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
├── 00-install-nginx-ingress.sh        # Installation script
├── 01-ingress-rec-ui.yaml             # REC UI Ingress
├── 02-tcp-configmap.yaml              # TCP services configuration
└── 03-patch-nginx-service.yaml        # LoadBalancer service patch
```

## 🚀 Installation

### Step 1: Install NGINX Ingress Controller

```bash
# Run installation script
./00-install-nginx-ingress.sh

# Or manually:
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"
```

**Note:** Adjust annotations for your cloud provider (EKS, GKE, AKS).

### Step 2: Wait for LoadBalancer

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx \
  -n ingress-nginx \
  --timeout=300s

# Get LoadBalancer IP/hostname
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### Step 3: Configure DNS

Create DNS records pointing to the LoadBalancer:

```
# REC UI
rec-ui.example.com → <LOADBALANCER-IP>

# Databases
db-test.example.com → <LOADBALANCER-IP>
db-cache.example.com → <LOADBALANCER-IP>
```

### Step 4: Deploy REC UI Ingress

```bash
# Update hostname in 01-ingress-rec-ui.yaml
# Then apply:
kubectl apply -f 01-ingress-rec-ui.yaml
```

### Step 5: Configure TCP Services for Databases

```bash
# Update database endpoints in 02-tcp-configmap.yaml
kubectl apply -f 02-tcp-configmap.yaml

# Patch NGINX service to expose database ports
kubectl apply -f 03-patch-nginx-service.yaml
```

## 📝 Configuration Files

### 01-ingress-rec-ui.yaml

Exposes REC UI on HTTPS (port 443).

**Key configurations:**
- TLS termination at ingress
- Backend uses HTTPS (port 8443)
- Self-signed certificate handling

### 02-tcp-configmap.yaml

Maps external TCP ports to internal database services.

**Format:**
```yaml
data:
  "12000": "redis-enterprise/test-db:12000"
  "12001": "redis-enterprise/cache-db:12001"
```

### 03-patch-nginx-service.yaml

Adds database ports to LoadBalancer service.

**Ports:**
- 443: HTTPS (REC UI)
- 12000: Database 1
- 12001: Database 2
- ... (add more as needed)

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

When creating a new database, update the TCP ConfigMap:

```bash
# 1. Edit 02-tcp-configmap.yaml
# Add new line:
#   "12002": "redis-enterprise/new-db:12002"

# 2. Apply changes
kubectl apply -f 02-tcp-configmap.yaml

# 3. Update LoadBalancer service
# Edit 03-patch-nginx-service.yaml to add port 12002
kubectl apply -f 03-patch-nginx-service.yaml

# 4. Wait for LoadBalancer update
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
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

