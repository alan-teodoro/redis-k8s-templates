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
# Format: --set tcp.<EXTERNAL_PORT>="<namespace>/<service>:<INTERNAL_PORT>"

# Example: Expose database on external port 12000
# (internal port may be different, check with: kubectl get svc -n redis-enterprise)
--set tcp.12000="redis-enterprise/test-db:10414"

# Multiple databases
--set tcp.12000="redis-enterprise/test-db:10414" \
--set tcp.12001="redis-enterprise/cache-db:11234"
```

**Important Notes:**
- **External port** (12000): Port exposed on the LoadBalancer (what clients connect to)
- **Internal port** (10414): Port of the Kubernetes service (check with `kubectl get svc`)
- The external and internal ports can be different
- To find the internal port: `kubectl get svc <db-name> -n redis-enterprise`

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

# Test HTTPS access (with Host header)
curl -k -I https://${LB_HOST} -H "Host: rec-ui.example.com"
```

**Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

**Note:** You need to either:
1. Configure DNS to point `rec-ui.example.com` to the LoadBalancer, OR
2. Use `curl` with `-H "Host: rec-ui.example.com"` header, OR
3. Add to `/etc/hosts`: `<LB-IP> rec-ui.example.com`

### Database Access

```bash
# Test database connection via TCP port 12000
redis-cli -h ${LB_HOST} \
  -p 12000 \
  --tls \
  --insecure \
  -a RedisAdmin123! \
  PING
```

**Expected:** `PONG`

**Note:** The database is accessed directly via TCP passthrough on port 12000.

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

## ✅ Verification

### Check Installation

```bash
# Check NGINX pods
kubectl get pods -n ingress-nginx

# Check LoadBalancer service and ports
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Check Ingress resources
kubectl get ingress -n redis-enterprise

# Check TCP ConfigMap (created by Helm)
kubectl get configmap tcp-services -n ingress-nginx -o yaml
```

### Verify Database Port Mapping

**Important:** The database service port may be different from the external port!

```bash
# 1. Find the internal port of your database service
kubectl get svc test-db -n redis-enterprise
# Example output: test-db   ClusterIP   10.100.86.188   <none>   10414/TCP
#                                                                  ^^^^^ This is the internal port

# 2. Check Helm values to see TCP mappings
helm get values ingress-nginx -n ingress-nginx

# 3. Verify the ConfigMap has correct mapping
kubectl get configmap tcp-services -n ingress-nginx -o yaml
# Should show: "12000": redis-enterprise/test-db:10414
#               ^^^^^                              ^^^^^
#            External port                    Internal port
```

### Test Connectivity

```bash
# Get LoadBalancer hostname
LB_HOST=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "LoadBalancer: ${LB_HOST}"

# Test REC UI (HTTPS)
curl -k -I https://${LB_HOST} -H "Host: rec-ui.example.com"
# Expected: HTTP/2 200

# Test Database (TCP)
# First get the database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Then test connection (use EXTERNAL port 12000)
redis-cli -h ${LB_HOST} -p 12000 --tls --insecure -a ${DB_PASS} PING
# Expected: PONG
```

## 🔍 Troubleshooting

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n redis-enterprise
kubectl describe ingress rec-ui -n redis-enterprise

# Check NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Verify backend service exists
kubectl get svc rec-ui -n redis-enterprise
```

### TCP Services Not Working

**Common issue:** Wrong internal port in TCP mapping!

```bash
# 1. Verify the database service port
kubectl get svc <db-name> -n redis-enterprise
# Note the port number (e.g., 10414)

# 2. Check if ConfigMap has correct mapping
kubectl get configmap tcp-services -n ingress-nginx -o yaml
# Should be: "12000": "redis-enterprise/<db-name>:<INTERNAL_PORT>"

# 3. If wrong, update via Helm
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --reuse-values \
  --set tcp.12000="redis-enterprise/<db-name>:<CORRECT_INTERNAL_PORT>"

# 4. Check if ports are exposed on LoadBalancer
kubectl get svc ingress-nginx-controller -n ingress-nginx
# Should show: 12000:XXXXX/TCP

# 5. Test connectivity
telnet <LOADBALANCER-IP> 12000
```

### TLS Certificate Issues

```bash
# Check REC UI certificate
openssl s_client -connect <LOADBALANCER-IP>:443 -servername rec-ui.example.com

# For databases (TLS passthrough)
openssl s_client -connect <LOADBALANCER-IP>:12000
```

### Authentication Failed

```bash
# Get the correct database password
kubectl get secret redb-<db-name> -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d

# Test with correct password
redis-cli -h <LOADBALANCER-IP> -p 12000 --tls --insecure -a <PASSWORD> PING
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

