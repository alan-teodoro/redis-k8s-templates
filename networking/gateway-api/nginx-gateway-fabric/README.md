# NGINX Gateway Fabric

NGINX Gateway Fabric is the **official successor** to NGINX Ingress Controller, implementing the Kubernetes Gateway API standard.

## Overview

Gateway API is the **modern standard** for Kubernetes ingress, replacing the legacy Ingress API. It provides:

- ✅ **Role-oriented design** - Separation between infrastructure (Gateway) and routing (HTTPRoute)
- ✅ **Expressive routing** - Headers, methods, query params, weighted traffic splitting
- ✅ **Portable** - Works with any Gateway API implementation (NGINX, Envoy, Istio, etc.)
- ✅ **Type-safe** - Strongly typed resources with validation

### Why Gateway API?

**NGINX Ingress Controller is retiring** (March 2026). Gateway API is the recommended replacement.

**Benefits:**
- Standard API across all vendors
- More powerful routing capabilities
- Better separation of concerns
- Active development and community support

---

## Prerequisites

1. ✅ **Gateway API CRDs** installed (Standard Channel)
2. ✅ **NGINX Gateway Fabric** controller installed
3. ✅ **Redis Enterprise database** running

---

## Installation

### 1. Install Gateway API CRDs

```bash
# Install Standard Channel (Gateway, HTTPRoute, GRPCRoute)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
```

### 2. Install NGINX Gateway Fabric

```bash
# Install via OCI registry
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace \
  --namespace nginx-gateway
```

### 3. Verify Installation

```bash
# Check controller pod
kubectl get pods -n nginx-gateway

# Check GatewayClass
kubectl get gatewayclass

# Expected output:
# NAME    CONTROLLER                                   ACCEPTED   AGE
# nginx   gateway.nginx.org/nginx-gateway-controller   True       1m
```

---

## Quick Start

### Step 1: Create TLS Certificate (Frontend)

For testing, create a self-signed certificate for the Gateway (client-facing):

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=redis.example.com/O=redis"

# Create Kubernetes secret
kubectl create secret tls redis-tls-cert \
  -n nginx-gateway \
  --cert=tls.crt \
  --key=tls.key

# Clean up local files
rm tls.key tls.crt
```

**For production**, use cert-manager with Let's Encrypt.

### Step 1b: Extract Backend CA Certificate

For backend TLS validation, extract the Redis Enterprise CA certificate:

```bash
# Extract CA certificate from REC pod
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  cat /etc/opt/redislabs/proxy_cert.pem > rec-ca.crt

# For rec-ui (which uses self-signed certificate), extract the certificate itself
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  openssl s_client -connect rec-ui.redis-enterprise.svc.cluster.local:8443 -showcerts </dev/null 2>/dev/null | \
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > rec-ui-cert.pem

# Create ConfigMap with the CA certificate
kubectl create configmap rec-backend-ca-cert \
  --from-file=ca.crt=rec-ui-cert.pem \
  -n redis-enterprise

# Clean up local files
rm rec-ca.crt rec-ui-cert.pem
```

**Note:** For self-signed certificates, the certificate itself serves as the CA.

### Step 2: Create Gateway

The Gateway creates a LoadBalancer Service (AWS ELB):

```bash
kubectl apply -f gateway.yaml
```

Wait for the Gateway to be ready:

```bash
kubectl wait --for=condition=Programmed gateway/redis-gateway -n nginx-gateway --timeout=5m
```

Get the LoadBalancer address:

```bash
kubectl get gateway redis-gateway -n nginx-gateway

# Get external hostname
GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Gateway Hostname: $GATEWAY_HOSTNAME"

# Resolve to IP address (needed for curl --resolve)
GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)
echo "Gateway IP: $GATEWAY_IP"
```

**Expected output:**
```
NAME            CLASS   ADDRESS                                                                  PROGRAMMED   AGE
redis-gateway   nginx   a17d24eee96a54907b099962bc73ecbb-218736380.us-east-1.elb.amazonaws.com   True         2m
```

### Step 3: Create BackendTLSPolicy

Create a BackendTLSPolicy to validate backend TLS certificates:

```bash
# Apply ConfigMap with CA certificate (created in Step 1b)
kubectl apply -f backend-tls-configmap.yaml

# Apply BackendTLSPolicy
kubectl apply -f backend-tls-policy.yaml
```

Verify the BackendTLSPolicy:

```bash
kubectl describe backendtlspolicy rec-ui-backend-tls -n redis-enterprise
```

**Expected status:**
```
Status:
  Ancestors:
    Conditions:
      Status:  True
      Type:    ResolvedRefs
      Status:  True
      Type:    Accepted
```

### Step 4: Create HTTPRoute

Create an HTTPRoute to route traffic to Redis Enterprise UI:

```bash
kubectl apply -f httproute-rec-ui.yaml
```

Verify the HTTPRoute:

```bash
kubectl get httproute rec-ui-route -n redis-enterprise
kubectl describe httproute rec-ui-route -n redis-enterprise
```

**Expected status:**
```
Status:
  Parents:
    Conditions:
      Status:  True
      Type:    Accepted
      Status:  True
      Type:    ResolvedRefs
```

### Step 5: Test Connectivity

Test with curl (requires SNI):

```bash
# Test HTTPS with SNI (using --resolve)
curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
```

**Expected output:** HTML from Redis Enterprise UI

**Note:** Using `-H "Host: ui.redis.example.com"` won't work because it doesn't set SNI for TLS handshake. Use `--resolve` instead.

### Step 6: Access in Browser

Add to `/etc/hosts`:

```bash
# Add DNS entry
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts
```

Open in browser:

```bash
# macOS
open https://ui.redis.example.com

# Linux
xdg-open https://ui.redis.example.com
```

**Note:** You'll see a certificate warning (self-signed cert). Accept it to proceed.

**Default credentials:**
- Username: `demo@redis.com`
- Password: Get from secret:
  ```bash
  kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
  ```

---

## Architecture

### Traffic Flow

```
Client (Browser/curl)
    ↓ HTTPS (TLS with SNI: ui.redis.example.com)
AWS ELB (LoadBalancer)
    ↓ HTTPS
Gateway (nginx-gateway namespace)
    ├─ Terminates client TLS
    ├─ Validates backend TLS certificate
    └─ Re-encrypts to backend
    ↓ HTTPS (validated with CA cert)
HTTPRoute (routing rules)
    ↓
rec-ui Service (redis-enterprise namespace)
    ↓ Port 8443 (HTTPS)
Redis Enterprise Pods (rec-0, rec-1, rec-2)
```

### Components

| Component | Type | Purpose |
|-----------|------|---------|
| **GatewayClass** | Cluster-scoped | Defines controller (nginx) |
| **Gateway** | Namespaced | Creates LoadBalancer, defines listeners, terminates TLS |
| **BackendTLSPolicy** | Namespaced | Configures backend TLS validation |
| **HTTPRoute** | Namespaced | Routes traffic to backend services |
| **ConfigMap** | Namespaced | Stores CA certificate for backend validation |
| **Service** | Namespaced | Redis Enterprise UI endpoint |

### TLS Flow

1. **Client → Gateway (Frontend TLS)**
   - Client connects with SNI: `ui.redis.example.com`
   - Gateway presents certificate from `redis-tls-cert` secret
   - Gateway terminates TLS

2. **Gateway → Backend (Backend TLS)**
   - Gateway initiates new HTTPS connection to `rec-ui:8443`
   - Gateway validates backend certificate using CA from ConfigMap
   - Backend presents self-signed certificate
   - Gateway verifies: `CN=rec.redis-enterprise.svc.cluster.local`

---

## Configuration Examples

### HTTP to HTTPS Redirect

See `httproute.yaml` for automatic HTTP → HTTPS redirect configuration.

### Custom Domain

Update the Gateway with your domain:

```yaml
listeners:
- name: https
  hostname: redis.yourdomain.com
  protocol: HTTPS
  port: 443
```

### Multiple Databases

Create multiple HTTPRoutes with different hostnames:

```yaml
# Database 1
spec:
  hostnames:
  - db1.example.com
  
# Database 2
spec:
  hostnames:
  - db2.example.com
```

---

## Troubleshooting

### Gateway not ready

**Problem:** Gateway stuck in `Pending` or `NotReady`

**Solution:** Check Gateway status:

```bash
kubectl describe gateway redis-gateway -n nginx-gateway
```

Common issues:
- LoadBalancer service not created (check cloud provider)
- TLS certificate secret not found
- Invalid listener configuration

### HTTPRoute not working

**Problem:** Traffic not reaching database

**Solution:** Check HTTPRoute status:

```bash
kubectl describe httproute redis-route -n redis-enterprise
```

Common issues:
- Backend service not found
- Namespace mismatch
- ReferenceGrant missing (cross-namespace)

### TLS certificate issues

**Problem:** Certificate errors

**Solution:** Verify certificate:

```bash
kubectl get secret redis-tls-cert -n nginx-gateway
openssl s_client -connect $GATEWAY_IP:443 -servername ui.redis.example.com
```

### 421 Misdirected Request

**Problem:** `421 Misdirected Request` error

**Cause:** SNI (Server Name Indication) mismatch or missing hostname in Gateway listener.

**Solution:**

1. Verify Gateway listener has `hostname` configured:
   ```bash
   kubectl get gateway redis-gateway -n nginx-gateway -o yaml | grep hostname
   ```

2. Use `curl --resolve` instead of `-H "Host:"` to set SNI correctly:
   ```bash
   # Wrong (doesn't set SNI)
   curl -k -H "Host: ui.redis.example.com" https://$GATEWAY_IP

   # Correct (sets both Host header and SNI)
   curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
   ```

### 502 Bad Gateway

**Problem:** `502 Bad Gateway` error

**Cause:** Backend TLS validation failure.

**Solution:**

1. Check NGINX logs for SSL errors:
   ```bash
   # Get NGINX data plane pod
   NGINX_POD=$(kubectl get pods -n nginx-gateway -o name | grep redis-gateway-nginx)
   kubectl logs -n nginx-gateway $NGINX_POD --tail=50
   ```

2. Common errors:
   - `upstream SSL certificate verify error: (18:self-signed certificate)` → CA certificate mismatch
   - `upstream SSL certificate verify error: (20:unable to get local issuer certificate)` → Missing CA certificate

3. Verify BackendTLSPolicy status:
   ```bash
   kubectl describe backendtlspolicy rec-ui-backend-tls -n redis-enterprise
   ```

4. For self-signed certificates, extract the certificate itself (not a separate CA):
   ```bash
   kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
     openssl s_client -connect rec-ui.redis-enterprise.svc.cluster.local:8443 -showcerts </dev/null 2>/dev/null | \
     sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > rec-ui-cert.pem

   kubectl create configmap rec-backend-ca-cert \
     --from-file=ca.crt=rec-ui-cert.pem \
     -n redis-enterprise \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

### DNS resolution issues

**Problem:** Cannot resolve hostname

**Solution:**

```bash
# Get Gateway IP
GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)

# Add to /etc/hosts
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts

# Verify
cat /etc/hosts | grep redis.example.com
```

---

## Next Steps

- **Production TLS**: Use cert-manager with Let's Encrypt
- **Custom Policies**: Configure timeouts, retries, rate limiting
- **Monitoring**: Integrate with Prometheus/Grafana
- **Multiple Environments**: Separate Gateways for dev/staging/prod

---

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric Docs](https://docs.nginx.com/nginx-gateway-fabric/)
- [Gateway API vs Ingress](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
- [NGINX Ingress Retirement](https://kubernetes.io/blog/2024/12/ingress-nginx-retirement/)

