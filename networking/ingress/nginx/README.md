# NGINX Ingress Controller for Redis Enterprise

Traditional Kubernetes Ingress configuration for exposing Redis Enterprise Cluster UI and databases.

## 📋 Overview

This configuration uses the NGINX Ingress Controller to provide external access to:
- **REC UI** (port 8443) - HTTPS with TLS termination
- **Redis Databases** (port 12000+) - TCP with TLS passthrough

## 🏗️ Architecture

```
                                    ┌─────────────────────────────┐
                                    │   NGINX Ingress Controller  │
                                    │   (LoadBalancer Service)    │
                                    └──────────┬──────────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
            ┌───────▼────────┐        ┌────────▼────────┐       ┌────────▼────────┐
            │  Ingress (UI)  │        │ TCP ConfigMap   │       │ TCP ConfigMap   │
            │  HTTPS (443)   │        │ Database (12000)│       │ Database (12001)│
            └───────┬────────┘        └────────┬────────┘       └────────┬────────┘
                    │                          │                          │
            ┌───────▼────────┐        ┌────────▼────────┐       ┌────────▼────────┐
            │  REC Service   │        │  DB Service     │       │  DB Service     │
            │  rec-ui:8443   │        │  test-db:12000  │       │  cache-db:12001 │
            └────────────────┘        └─────────────────┘       └─────────────────┘
```

## 📁 Files

```
nginx/
├── README.md                          # This file
└── 01-ingress-rec-ui.yaml             # REC UI Ingress
```

**Note:** TCP services for databases are configured via Helm values (`--set tcp.PORT="namespace/service:port"`).

## 🚀 Installation

### Step 1: Install NGINX Ingress Controller with TCP Support

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install for AWS EKS with TCP port 12000 for database
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
  --set tcp.12000="redis-enterprise/test-db:12000"

# For GKE
# helm install ingress-nginx ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --create-namespace \
#   --set controller.service.type=LoadBalancer \
#   --set tcp.12000="redis-enterprise/test-db:12000"

# For AKS
# helm install ingress-nginx ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --create-namespace \
#   --set controller.service.type=LoadBalancer \
#   --set tcp.12000="redis-enterprise/test-db:12000"

# For vanilla Kubernetes
# helm install ingress-nginx ingress-nginx/ingress-nginx \
#   --namespace ingress-nginx \
#   --create-namespace \
#   --set controller.service.type=LoadBalancer \
#   --set tcp.12000="redis-enterprise/test-db:12000"
```

**Note:** The `--set tcp.12000="redis-enterprise/test-db:12000"` configures TCP passthrough for the database on port 12000.

### Step 2: Wait for LoadBalancer

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx \
  -n ingress-nginx \
  --timeout=300s

# Get LoadBalancer hostname (wait for EXTERNAL-IP)
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### Step 3: Deploy REC UI Ingress

```bash
# Apply REC UI Ingress
kubectl apply -f 01-ingress-rec-ui.yaml
```

**Note:** Update the hostname in `01-ingress-rec-ui.yaml` before applying if needed.

## 📝 Configuration

### REC UI Ingress (01-ingress-rec-ui.yaml)

Exposes REC UI on HTTPS (port 443).

**Key configurations:**
- `ingressClassName: nginx` - Uses NGINX Ingress Controller
- `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` - Backend uses HTTPS
- `nginx.ingress.kubernetes.io/proxy-ssl-verify: "false"` - Accepts self-signed certificates
- Backend service: `rec-ui:8443`

**Update before applying:**
```yaml
rules:
  - host: rec-ui.example.com  # ⚠️ Change to your domain
```

### TCP Services (Configured via Helm)

Database TCP ports are configured during Helm install/upgrade:

```bash
# Single database
--set tcp.12000="redis-enterprise/test-db:12000"

# Multiple databases
--set tcp.12000="redis-enterprise/test-db:12000" \
--set tcp.12001="redis-enterprise/cache-db:12001"
```

This automatically:
- Creates a ConfigMap with TCP service mappings
- Exposes ports on the LoadBalancer service
- Configures NGINX to proxy TCP traffic

## 🔐 Access

### REC UI

```bash
# Get LoadBalancer hostname
LB_HOST=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "REC UI: https://${LB_HOST}"
```

**Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

### Database Access

```bash
# Test database connection
redis-cli -h ${LB_HOST} \
  -p 12000 \
  --tls \
  --insecure \
  -a RedisAdmin123! \
  PING
```

**Expected:** `PONG`

## 🔧 Adding New Databases

When creating a new database, upgrade the Helm release to add the new TCP port:

```bash
# Add database on port 12001
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --reuse-values \
  --set tcp.12001="redis-enterprise/cache-db:12001"

# Add multiple databases at once
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --reuse-values \
  --set tcp.12001="redis-enterprise/cache-db:12001" \
  --set tcp.12002="redis-enterprise/session-db:12002"

# Verify ports are exposed
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## 🔍 Troubleshooting

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n redis-enterprise
kubectl describe ingress rec-ui -n redis-enterprise

# Check NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

### TCP Services Not Working

```bash
# Verify ConfigMap
kubectl get configmap tcp-services -n ingress-nginx -o yaml

# Check if ports are exposed on LoadBalancer
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Test connectivity
telnet <LOADBALANCER-IP> 12000
```

### TLS Certificate Issues

```bash
# Check certificate
openssl s_client -connect <LOADBALANCER-IP>:443 -servername rec-ui.example.com

# For databases (TLS passthrough)
openssl s_client -connect <LOADBALANCER-IP>:12000
```

## 🧹 Cleanup

```bash
# Remove configurations
kubectl delete -f 01-ingress-rec-ui.yaml
kubectl delete -f 02-tcp-configmap.yaml

# Uninstall NGINX Ingress
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## 📚 Additional Resources

- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [TCP/UDP Services](https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/)
- [TLS/HTTPS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)

