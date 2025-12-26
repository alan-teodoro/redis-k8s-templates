# Testing Guide - NGINX Gateway Fabric

This document describes the testing performed and results for NGINX Gateway Fabric with Redis Enterprise.

## Test Environment

- **Kubernetes**: EKS 1.31
- **NGINX Gateway Fabric**: 2.3.0
- **Redis Enterprise**: 8.0.6
- **Gateway API**: v1.4.1 (Standard Channel)

---

## Test 1: REC UI Access via HTTPRoute ✅ PASSED

### Objective
Access Redis Enterprise Cluster UI through Gateway API using HTTPS with backend TLS validation.

### Configuration

**Components:**
- Gateway: `redis-gateway` (nginx-gateway namespace)
- HTTPRoute: `rec-ui-route` (redis-enterprise namespace)
- BackendTLSPolicy: `rec-ui-backend-tls` (redis-enterprise namespace)
- Backend Service: `rec-ui:8443` (HTTPS with self-signed certificate)

**Traffic Flow:**
```
Client (curl/browser)
  ↓ HTTPS (SNI: ui.redis.example.com)
AWS ELB
  ↓ HTTPS
Gateway (terminates client TLS)
  ↓ HTTPS (validates backend cert with CA)
rec-ui Service (port 8443)
  ↓
REC Pods
```

### Test Steps

1. **Extract backend CA certificate:**
   ```bash
   kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
     openssl s_client -connect rec-ui.redis-enterprise.svc.cluster.local:8443 -showcerts </dev/null 2>/dev/null | \
     sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > rec-ui-cert.pem
   ```

2. **Create ConfigMap with CA:**
   ```bash
   kubectl create configmap rec-backend-ca-cert \
     --from-file=ca.crt=rec-ui-cert.pem \
     -n redis-enterprise
   ```

3. **Apply BackendTLSPolicy:**
   ```bash
   kubectl apply -f backend-tls-policy.yaml
   ```

4. **Apply HTTPRoute:**
   ```bash
   kubectl apply -f httproute-rec-ui.yaml
   ```

5. **Test with curl:**
   ```bash
   GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
   GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)
   curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
   ```

### Results

**Status:** ✅ **SUCCESS**

**Output:**
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="/static/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="csrf-token" content="{{ csrf_token() }} " />
    <title>Redis Enterprise</title>
    ...
```

**Verification:**
```bash
# BackendTLSPolicy status
kubectl describe backendtlspolicy rec-ui-backend-tls -n redis-enterprise
# Status: Accepted=True, ResolvedRefs=True

# HTTPRoute status
kubectl describe httproute rec-ui-route -n redis-enterprise
# Status: Accepted=True, ResolvedRefs=True

# Gateway status
kubectl get gateway redis-gateway -n nginx-gateway
# Status: Programmed=True
```

### Browser Access

Add to `/etc/hosts`:
```bash
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts
```

Open browser:
```bash
open https://ui.redis.example.com
```

**Login credentials:**
- Username: `demo@redis.com`
- Password: `kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d`

---

## Issues Encountered and Solutions

### Issue 1: 421 Misdirected Request

**Cause:** Missing `hostname` in Gateway listener configuration.

**Solution:** Added `hostname: "*.redis.example.com"` to Gateway HTTPS listener.

### Issue 2: 502 Bad Gateway - SSL Certificate Verify Error

**Cause:** Backend TLS validation failure. The rec-ui service uses a self-signed certificate.

**Solution:** 
- Extracted the self-signed certificate itself (not a separate CA)
- Created ConfigMap with the certificate
- Applied BackendTLSPolicy referencing the ConfigMap

**Key Learning:** For self-signed certificates, the certificate itself serves as the CA.

### Issue 3: curl with -H "Host:" not working

**Cause:** `-H "Host:"` only sets HTTP header, not SNI for TLS handshake.

**Solution:** Use `curl --resolve` to set both Host header and SNI correctly.

---

## Test 2: Database Access via TLSRoute ✅ PASSED

### Objective
Access Redis database through Gateway API using TLS passthrough (no TLS termination at Gateway).

### Configuration

**Components:**
- Gateway: `redis-gateway` with TLS passthrough listener (port 6379)
- TLSRoute: `redis-db-tls-route` (redis-enterprise namespace)
- Backend Service: `test-db:10414` (TLS enabled)
- Experimental features: Enabled in NGINX Gateway Fabric

**Traffic Flow:**
```
Client (redis-cli)
  ↓ TLS (SNI: db.redis.example.com)
AWS Classic Load Balancer (port 6379)
  ↓ TLS passthrough
NGINX Gateway Fabric (TLS preread + SNI routing)
  ↓ TLS passthrough (does NOT terminate)
Redis Database Service (test-db:10414)
  ↓ TLS termination
Redis Enterprise
```

### Prerequisites

1. **Enable experimental features in NGINX Gateway Fabric:**
   ```bash
   kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f -

   helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
     -n nginx-gateway \
     --set nginxGateway.gwAPIExperimentalFeatures.enable=true
   ```

2. **Enable TLS on database:**
   ```bash
   kubectl patch redb test-db -n redis-enterprise --type=merge -p '{"spec":{"tlsMode":"enabled"}}'
   ```

### Test Steps

1. **Apply TLSRoute:**
   ```bash
   kubectl apply -f tlsroute-database.yaml
   ```

2. **Verify TLSRoute status:**
   ```bash
   kubectl get tlsroute redis-db-tls-route -n redis-enterprise -o jsonpath='{.status.parents[0].conditions}' | jq
   ```

3. **Configure DNS:**
   ```bash
   GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
   GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)
   echo "$GATEWAY_IP db.redis.example.com" | sudo tee -a /etc/hosts
   ```

4. **Test connection:**
   ```bash
   DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

   # PING
   redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD PING

   # SET/GET
   redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD SET test "hello from gateway"
   redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD GET test
   ```

### Results

**Status:** ✅ **SUCCESS**

**Output:**
```bash
$ redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD PING
PONG

$ redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD SET test "hello from gateway"
OK

$ redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD GET test
"hello from gateway"

$ redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD INFO server
# Server
redis_version:8.2.1
redis_mode:standalone
...
```

**Verification:**
```bash
# TLSRoute status
kubectl get tlsroute redis-db-tls-route -n redis-enterprise
# Conditions: Accepted=True, ResolvedRefs=True

# Gateway listener
kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.spec.listeners[*].name}'
# Output: http https tls-passthrough

# LoadBalancer ports
kubectl get svc redis-gateway-nginx -n nginx-gateway
# Ports: 80, 443, 6379
```

### Issues Encountered and Solutions

**Issue 1: TLSRoute not processed (no status)**
- **Cause:** Experimental features not enabled in NGINX Gateway Fabric
- **Solution:** Reinstall with `--set nginxGateway.gwAPIExperimentalFeatures.enable=true`

**Issue 2: BackendNotFound in TLSRoute status**
- **Cause:** Wrong service name (`redis-10414` instead of `test-db`)
- **Solution:** Updated TLSRoute to reference correct service name

**Issue 3: SSL_connect failed: record layer failure**
- **Cause:** Database not configured for TLS
- **Solution:** Enabled TLS with `kubectl patch redb test-db -n redis-enterprise --type=merge -p '{"spec":{"tlsMode":"enabled"}}'`

**Issue 4: Port 6379 not accessible (connection timeout)**
- **Cause:** LoadBalancer listener not created when listener added after Gateway creation
- **Solution:** Delete and recreate Gateway to force LoadBalancer update

**Note:** Gateway annotation for NLB (`service.beta.kubernetes.io/aws-load-balancer-type: "nlb"`) doesn't propagate automatically. Classic LB works but is less efficient for TLS passthrough.

---

## Next Tests

- [ ] Test 3: Multiple databases with different hostnames
- [ ] Test 4: Envoy Gateway implementation
- [ ] Test 5: Istio Gateway API implementation

---

## References

- [NGINX Gateway Fabric - Secure Backend](https://docs.nginx.com/nginx-gateway-fabric/traffic-security/secure-backend/)
- [Gateway API BackendTLSPolicy](https://gateway-api.sigs.k8s.io/api-types/backendtlspolicy/)
- [Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)

