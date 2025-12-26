# HAProxy Ingress Controller for Redis Enterprise

High-performance HAProxy-based Ingress configuration for Redis Enterprise.

## 📋 Overview

HAProxy Ingress provides:
- **High performance** load balancing
- **Advanced routing** capabilities
- **Excellent TLS passthrough** support via SNI
- **TCP/HTTP** protocol support

## 📖 How It Works

HAProxy Ingress handles **two different types of traffic**:

### 1. **HTTP/HTTPS Traffic (REC UI)** ✅ Uses Ingress Resource
- Protocol: HTTP/HTTPS
- Configuration: Kubernetes `Ingress` resource
- File: `01-ingress-rec-ui.yaml`
- Routing: Based on hostname (`rec-ui.example.com`)
- Port: 80 (HTTP) / 443 (HTTPS with TLS cert)

### 2. **TLS Passthrough (Databases)** ✅ Uses Ingress with SNI
- Protocol: TLS (encrypted TCP)
- Configuration: Kubernetes `Ingress` resource with `ssl-passthrough` annotation
- File: `02-ingress-database.yaml`
- Routing: Based on **SNI hostname** (`db-test.example.com`)
- Port: **443** (shared with HTTPS, routed by SNI)

**🔑 Key Difference from NGINX:**
- **NGINX Ingress**: Databases use dedicated ports (12000, 12001) via Helm values
- **HAProxy Ingress**: Databases use port 443 with SNI-based routing via Ingress resources

**Advantage:** All traffic goes through standard ports (80/443), easier for firewall rules.

## 🏗️ Architecture

```
┌─────────────────────────────┐
│  HAProxy Ingress Controller │
│   (LoadBalancer Service)    │
└──────────┬──────────────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼────┐   ┌───▼────┐
│ REC UI │   │   DB   │
│  :8443 │   │ :12000 │
└────────┘   └────────┘
```

## 📁 Files

```
haproxy/
├── README.md                          # This file
├── 01-ingress-rec-ui.yaml             # REC UI Ingress
└── 02-ingress-database.yaml           # Database Ingress (TLS passthrough)
```

## 🚀 Installation

### Step 1: Install HAProxy Ingress Controller

**⚠️ Important:** Use version **0.14.10** (v0.15.0 has compatibility issues with Gateway API v1)

```bash
# Add Helm repository
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

# Install HAProxy Ingress (AWS EKS example)
helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --version 0.14.10 \
  --namespace ingress-haproxy \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"

# For GKE or AKS, remove the AWS-specific annotations:
# helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
#   --version 0.14.10 \
#   --namespace ingress-haproxy \
#   --create-namespace \
#   --set controller.service.type=LoadBalancer
```

### Step 2: Create IngressClass

**⚠️ Important:** The Helm chart doesn't create IngressClass automatically. Create it manually:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: haproxy
spec:
  controller: haproxy-ingress.github.io/controller
EOF
```

### Step 3: Wait for LoadBalancer

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=haproxy-ingress \
  -n ingress-haproxy \
  --timeout=300s

# Get LoadBalancer IP/hostname
kubectl get svc haproxy-ingress -n ingress-haproxy
```

### Step 4: Deploy Ingress Resources

```bash
kubectl apply -f networking/ingress/haproxy/01-ingress-rec-ui.yaml
kubectl apply -f networking/ingress/haproxy/02-ingress-database.yaml
```

### Step 5: Verify

```bash
# Check Ingress resources
kubectl get ingress -n redis-enterprise

# Should show:
# NAME             CLASS     HOSTS                 ADDRESS   PORTS   AGE
# rec-ui           haproxy   rec-ui.example.com              80      1m
# redis-database   haproxy   db-test.example.com             80      1m
```

## 📝 Configuration Files

### 01-ingress-rec-ui.yaml

Exposes REC UI with HTTPS.

**Key features:**
- TLS termination
- Backend HTTPS support
- Self-signed certificate handling

### 02-ingress-database.yaml

Exposes databases with TLS passthrough.

**Key features:**
- SNI-based routing
- TLS passthrough (no termination)
- TCP load balancing

## ✅ Testing

### Test REC UI

```bash
# Get LoadBalancer hostname
LB_HOST=$(kubectl get svc haproxy-ingress -n ingress-haproxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test via HTTP (port 80)
curl -I http://${LB_HOST} -H "Host: rec-ui.example.com"
# Expected: HTTP/1.1 200 OK

# Access via browser (HTTP)
echo "REC UI: http://${LB_HOST}"
# Use Host header: rec-ui.example.com
```

**Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

**Note:** HTTPS (port 443) requires TLS certificate configuration in the Ingress spec. For production, add a `tls` section with your certificate.

### Test Database

**⚠️ Important:** HAProxy uses **port 443 with SNI** for TLS passthrough (not a dedicated port like NGINX).

```bash
# Get database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Test connection via TLS with SNI
redis-cli -h ${LB_HOST} -p 443 \
  --tls --insecure \
  --sni db-test.example.com \
  -a ${DB_PASS} \
  PING
# Expected: PONG
```

**Key Difference from NGINX:**
- **NGINX Ingress**: Uses dedicated ports (12000, 12001, etc.) for TCP passthrough
- **HAProxy Ingress**: Uses port 443 with SNI-based routing for TLS passthrough

## 🔐 Access
redis-cli -h db-test.example.com \
  -p 443 \
  --tls \
  --sni db-test.example.com \
  -a RedisAdmin123! \
  PING
```

## 🔧 Advanced Configuration

### Custom Timeouts

Add annotations to Ingress:

```yaml
annotations:
  haproxy-ingress.github.io/timeout-client: "600s"
  haproxy-ingress.github.io/timeout-server: "600s"
```

### Rate Limiting

```yaml
annotations:
  haproxy-ingress.github.io/rate-limit: "100"
```

### SSL Passthrough

```yaml
annotations:
  haproxy-ingress.github.io/ssl-passthrough: "true"
  haproxy-ingress.github.io/ssl-passthrough-http-port: "8443"
```

## 🔍 Troubleshooting

### Check Ingress Status

```bash
kubectl get ingress -n redis-enterprise
kubectl describe ingress rec-ui -n redis-enterprise
```

### Check HAProxy Logs

```bash
kubectl logs -n ingress-haproxy -l app.kubernetes.io/name=haproxy-ingress --tail=50
```

### Verify Backend Connectivity

```bash
# Get HAProxy pod
POD=$(kubectl get pod -n ingress-haproxy -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].metadata.name}')

# Test backend
kubectl exec -it $POD -n ingress-haproxy -- curl -k https://rec-ui.redis-enterprise.svc.cluster.local:8443
```

## 🧹 Cleanup

```bash
kubectl delete -f 01-ingress-rec-ui.yaml
kubectl delete -f 02-ingress-database.yaml

helm uninstall haproxy-ingress -n ingress-haproxy
kubectl delete namespace ingress-haproxy
```

## 📚 Additional Resources

- [HAProxy Ingress Documentation](https://haproxy-ingress.github.io/)
- [Configuration Keys](https://haproxy-ingress.github.io/docs/configuration/keys/)
- [Examples](https://haproxy-ingress.github.io/docs/examples/)

