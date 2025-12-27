# Istio Service Mesh for Redis Enterprise

Configure Istio as an ingress controller for external access to Redis Enterprise databases and API.

---

## 📋 Overview

Istio provides advanced traffic management, security, and observability features through its service mesh architecture. Unlike traditional ingress controllers, Istio uses **Gateway** and **VirtualService** custom resources for routing.

**Key Differences from NGINX/HAProxy:**
- Uses native Istio resources (Gateway, VirtualService) instead of Kubernetes Ingress
- Provides advanced traffic management (retries, timeouts, circuit breakers)
- Built-in observability with distributed tracing
- mTLS between services
- **Hostname Restriction:** Only supports full leftmost wildcards (`*.example.com`) or FQDNs - **NO partial wildcards** (`*-redis.example.com`)

---

## ⚠️ Important: Hostname Restrictions

**Istio ONLY supports:**
- ✅ Full leftmost wildcards: `*.redis.example.com`
- ✅ Explicit FQDNs: `api.redis.example.com`, `db1.redis.example.com`

**Istio does NOT support:**
- ❌ Partial wildcards: `*-redis.example.com`
- ❌ Middle wildcards: `redis.*.example.com`

**Solution:** Always use **dot-prefixed** `dbFqdnSuffix` in REC configuration:
```yaml
ingressOrRouteSpec:
  method: istio
  apiFqdnUrl: api.redis.example.com
  dbFqdnSuffix: .redis.example.com  # ✅ Dot-prefixed
  # NOT: -redis.example.com          # ❌ Hyphen-prefixed (partial wildcard)
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    External Clients                         │
│              (api.redis.example.com:443)                    │
│              (db1.redis.example.com:443)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ DNS: *.redis.example.com → LoadBalancer IP
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Istio Ingress Gateway (LoadBalancer)           │
│                   namespace: istio-system                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Gateway: redis-gateway                               │  │
│  │  - Hosts: *.redis.example.com                        │  │
│  │  - Port: 443 (HTTPS)                                 │  │
│  │  - TLS Mode: PASSTHROUGH                             │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ SNI-based routing
                         │
┌────────────────────────▼────────────────────────────────────┐
│         VirtualService: redis-vs (namespace: redis-enterprise)│
│                                                             │
│  SNI: api.redis.example.com  → rec:9443 (REC API)          │
│  SNI: db1.redis.example.com  → db1:12000 (Database)        │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
┌───────▼────────┐              ┌─────────▼────────┐
│  REC Service   │              │ Database Service │
│  rec:9443      │              │ test-db:12000    │
│  (API/UI)      │              │ (Redis DB)       │
└────────────────┘              └──────────────────┘
```

---

## 📂 Directory Structure

```
networking/ingress/istio/
├── README.md                    # This file
├── 01-install-istio.md          # Istio installation guide
├── 02-gateway.yaml              # Istio Gateway resource
├── 03-virtualservice-rec.yaml   # VirtualService for REC API
├── 04-virtualservice-db.yaml    # VirtualService for database
└── 05-rec-istio.yaml            # REC with Istio configuration
```

---

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.23+
- Istio 1.24+ installed
- Redis Enterprise Operator installed
- DNS configured for `*.redis.example.com`

### Installation Steps

1. **Install Istio** (if not already installed):
   ```bash
   # See 01-install-istio.md for detailed instructions
   istioctl install --set profile=default -y
   ```

2. **Get Istio Ingress Gateway External IP**:
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system
   ```

3. **Configure DNS**:
   Create wildcard DNS record: `*.redis.example.com` → Istio LoadBalancer IP

4. **Deploy Gateway**:
   ```bash
   kubectl apply -f 02-gateway.yaml
   ```

5. **Deploy VirtualServices**:
   ```bash
   kubectl apply -f 03-virtualservice-rec.yaml
   kubectl apply -f 04-virtualservice-db.yaml
   ```

6. **Deploy REC with Istio configuration**:
   ```bash
   kubectl apply -f 05-rec-istio.yaml
   ```

---

## 🔧 How It Works

### 1. Gateway (Layer 4 Routing)

The **Gateway** resource configures the Istio Ingress Gateway to listen on port 443 with TLS passthrough:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: redis-gateway
spec:
  selector:
    istio: ingressgateway  # Matches Istio ingress gateway pods
  servers:
  - hosts:
    - '*.redis.example.com'  # Wildcard for all Redis services
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: PASSTHROUGH  # Required for Redis TLS
```

**Key Points:**
- `PASSTHROUGH` mode: Istio does NOT terminate TLS - passes encrypted traffic directly to backend
- Required for Redis databases (they handle TLS termination)
- SNI (Server Name Indication) is used for routing

### 2. VirtualService (SNI-based Routing)

The **VirtualService** resource routes traffic based on SNI hostname:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: redis-vs
spec:
  gateways:
  - redis-gateway
  hosts:
  - '*.redis.example.com'
  tls:
  - match:
    - port: 443
      sniHosts:
      - api.redis.example.com  # Route API traffic
    route:
    - destination:
        host: rec
        port:
          number: 9443
  - match:
    - port: 443
      sniHosts:
      - db1.redis.example.com  # Route database traffic
    route:
    - destination:
        host: test-db
        port:
          number: 12000
```

**Key Points:**
- Each SNI hostname maps to a specific Kubernetes service
- Multiple databases = multiple `tls.match` entries
- Service names must match actual Kubernetes service names

### 3. Traffic Flow

1. **Client** connects to `db1.redis.example.com:443` with SNI
2. **DNS** resolves to Istio Ingress Gateway LoadBalancer IP
3. **Gateway** accepts connection on port 443 (TLS passthrough enabled)
4. **VirtualService** reads SNI header and routes to `test-db:12000`
5. **Database** receives encrypted connection and handles TLS termination

---

## ✅ Verification

### Check Istio Installation

```bash
# Verify Istio is installed
kubectl get pods -n istio-system

# Get Ingress Gateway external IP
kubectl get svc istio-ingressgateway -n istio-system
```

Expected output:
```
NAME                   TYPE           EXTERNAL-IP      PORT(S)
istio-ingressgateway   LoadBalancer   <EXTERNAL_IP>    15021:...,80:...,443:...
```

### Check Gateway and VirtualService

```bash
# Check Gateway
kubectl get gateway -n redis-enterprise

# Check VirtualService
kubectl get virtualservice -n redis-enterprise

# Describe for details
kubectl describe gateway redis-gateway -n redis-enterprise
kubectl describe virtualservice redis-vs -n redis-enterprise
```

### Test REC API Access

```bash
# Get Istio LoadBalancer IP
ISTIO_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with curl (replace with your domain)
curl -k https://api.redis.example.com:443/v1/cluster \
  -u admin@redis.com:RedisAdmin123!

# Or test TLS handshake
openssl s_client -connect api.redis.example.com:443 \
  -servername api.redis.example.com
```

### Test Database Access

```bash
# Get database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Test with redis-cli
redis-cli -h db1.redis.example.com -p 443 \
  --tls --insecure \
  --sni db1.redis.example.com \
  -a $DB_PASS \
  PING

# Expected: PONG
```

### Test with OpenSSL

```bash
# Get proxy certificate from REC pod
kubectl exec -it rec-0 -n redis-enterprise -c redis-enterprise-node \
  -- cat /etc/opt/redislabs/proxy_cert.pem > proxy_cert.pem

# Test database connection
openssl s_client \
  -connect db1.redis.example.com:443 \
  -crlf -CAfile ./proxy_cert.pem \
  -servername db1.redis.example.com

# Type: PING
# Expected: +PONG
```

---

## 🔍 Troubleshooting

### Istio Webhook Error: "partial wildcard not allowed"

**Symptoms:**
```
admission webhook "validation.istio.io" denied the request:
configuration is invalid: partial wildcard "*-redis.example.com" not allowed
```

**Cause:** Using hyphen-prefixed suffix in REC configuration

**Solution:**
```yaml
# ❌ Wrong
ingressOrRouteSpec:
  dbFqdnSuffix: -redis.example.com

# ✅ Correct
ingressOrRouteSpec:
  dbFqdnSuffix: .redis.example.com
```

### Gateway Not Ready

**Check:**
```bash
kubectl describe gateway redis-gateway -n redis-enterprise
```

**Common Issues:**
1. **Selector mismatch**: Verify `istio: ingressgateway` label matches your Istio installation
   ```bash
   kubectl get pods -n istio-system -l istio=ingressgateway --show-labels
   ```

2. **Namespace mismatch**: Gateway must be in same namespace as VirtualService

### VirtualService Not Routing

**Check:**
```bash
kubectl describe virtualservice redis-vs -n redis-enterprise
```

**Common Issues:**
1. **Service name mismatch**: Ensure `destination.host` matches actual service name
   ```bash
   kubectl get svc -n redis-enterprise
   ```

2. **Port mismatch**: Verify service port matches VirtualService destination port

3. **SNI hostname mismatch**: Client must send correct SNI header

### DNS Resolution Fails

**Verify DNS:**
```bash
dig api.redis.example.com
dig db1.redis.example.com

# Should resolve to Istio LoadBalancer IP
```

**Fix:**
- Create wildcard DNS: `*.redis.example.com` → Istio LoadBalancer IP
- Or create individual A records for each hostname

### TLS Handshake Fails

**Symptoms:** `SSL handshake failed` or `certificate verify failed`

**Checks:**
1. **Verify TLS passthrough is enabled:**
   ```bash
   kubectl get gateway redis-gateway -n redis-enterprise -o yaml | grep mode
   # Should show: mode: PASSTHROUGH
   ```

2. **Verify client sends SNI:**
   ```bash
   openssl s_client -connect db1.redis.example.com:443 \
     -servername db1.redis.example.com \
     -showcerts
   ```

3. **Check database TLS is enabled:**
   ```bash
   kubectl get redb test-db -n redis-enterprise -o yaml | grep tlsMode
   # Should show: tlsMode: enabled
   ```

### Connection Timeout

**Checks:**
1. **Verify Istio LoadBalancer is accessible:**
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system
   ```

2. **Check security groups / firewall rules:**
   - Allow inbound port 443 to LoadBalancer
   - Allow outbound from LoadBalancer to cluster nodes

3. **Verify pods are running:**
   ```bash
   kubectl get pods -n redis-enterprise
   kubectl get pods -n istio-system
   ```

---

## 📊 Comparison: Istio vs NGINX vs HAProxy

| Feature | Istio | NGINX | HAProxy |
|---------|-------|-------|---------|
| **Resource Type** | Gateway + VirtualService | Ingress | Ingress |
| **Configuration** | Native Istio CRDs | Annotations | Annotations |
| **TLS Passthrough** | `mode: PASSTHROUGH` | Annotation | Annotation |
| **Wildcard Support** | Leftmost only (`*.example.com`) | Full support | Full support |
| **Database Routing** | SNI-based (port 443) | SNI-based (port 443) | SNI-based (port 443) |
| **Observability** | Built-in (Kiali, Jaeger) | External tools | External tools |
| **Traffic Management** | Advanced (retries, timeouts, etc.) | Basic | Basic |
| **Service Mesh** | Yes | No | No |
| **Complexity** | High | Low | Low |
| **Best For** | Microservices, advanced routing | Simple ingress | Simple ingress |

---

## 🎯 Best Practices

1. **Always use dot-prefixed `dbFqdnSuffix`** for Istio compatibility
   ```yaml
   dbFqdnSuffix: .redis.example.com  # ✅
   ```

2. **Use wildcard DNS** for easier management
   ```
   *.redis.example.com → Istio LoadBalancer IP
   ```

3. **Enable TLS on all databases** when using Istio ingress
   ```yaml
   spec:
     tlsMode: enabled
   ```

4. **Document hostname conventions** in deployment guides

5. **Keep Istio and Redis Operator versions aligned**

6. **Use Istio observability tools** (Kiali, Jaeger) for troubleshooting

7. **Test SNI support** in your client libraries before deployment

---

## 📚 Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [Redis Enterprise Istio Integration](https://redis.io/docs/latest/operate/kubernetes/networking/istio/)
- [Istio Hostname Validation](https://istio.io/latest/docs/ops/common-problems/network-issues/#partial-or-no-connectivity-between-services)

---

## 🔐 Security Considerations

1. **TLS Passthrough**: Istio does not inspect encrypted traffic - ensure databases handle TLS properly
2. **mTLS**: Consider enabling Istio mTLS for service-to-service communication
3. **Authorization Policies**: Use Istio AuthorizationPolicy for fine-grained access control
4. **Network Policies**: Combine with Kubernetes NetworkPolicy for defense in depth
5. **Certificate Management**: Use cert-manager for automated certificate rotation

---

## 📝 Notes

- Istio ingress is recommended for **microservices architectures** with advanced routing needs
- For simple ingress requirements, **NGINX or HAProxy** may be easier to configure
- Istio provides **built-in observability** (metrics, traces, logs) not available in traditional ingress controllers
- **Partial wildcard restriction** is specific to Istio - other controllers support it
- Istio can coexist with other ingress controllers in the same cluster



