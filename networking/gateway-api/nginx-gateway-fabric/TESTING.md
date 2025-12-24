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

## Next Tests

- [ ] Test 2: Database access via TLSRoute (TLS passthrough)
- [ ] Test 3: Multiple databases with different hostnames
- [ ] Test 4: Envoy Gateway implementation
- [ ] Test 5: Istio Gateway API implementation

---

## References

- [NGINX Gateway Fabric - Secure Backend](https://docs.nginx.com/nginx-gateway-fabric/traffic-security/secure-backend/)
- [Gateway API BackendTLSPolicy](https://gateway-api.sigs.k8s.io/api-types/backendtlspolicy/)
- [Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)

