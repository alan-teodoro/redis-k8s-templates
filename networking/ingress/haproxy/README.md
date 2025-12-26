# HAProxy Ingress Controller for Redis Enterprise

High-performance HAProxy-based Ingress configuration for Redis Enterprise.

## 📋 Overview

HAProxy Ingress provides:
- **High performance** load balancing
- **Advanced routing** capabilities
- **Excellent TLS passthrough** support
- **TCP/HTTP** protocol support

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
├── 00-install-haproxy-ingress.sh      # Installation script
├── 01-ingress-rec-ui.yaml             # REC UI Ingress
└── 02-ingress-database.yaml           # Database Ingress (TLS passthrough)
```

## 🚀 Installation

### Step 1: Install HAProxy Ingress Controller

```bash
# Run installation script
./00-install-haproxy-ingress.sh

# Or manually:
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --namespace ingress-haproxy \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Step 2: Wait for LoadBalancer

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=haproxy-ingress \
  -n ingress-haproxy \
  --timeout=300s

# Get LoadBalancer IP/hostname
kubectl get svc haproxy-ingress -n ingress-haproxy
```

### Step 3: Configure DNS

```
rec-ui.example.com → <LOADBALANCER-IP>
db-test.example.com → <LOADBALANCER-IP>
```

### Step 4: Deploy Ingress Resources

```bash
# Update hostnames in YAML files
kubectl apply -f 01-ingress-rec-ui.yaml
kubectl apply -f 02-ingress-database.yaml
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

## 🔐 Access

### REC UI

```bash
LB_HOST=$(kubectl get svc haproxy-ingress -n ingress-haproxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "REC UI: https://${LB_HOST}"
```

**Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

### Database Access

```bash
# Test connection
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

