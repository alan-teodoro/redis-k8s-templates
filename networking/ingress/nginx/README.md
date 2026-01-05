# NGINX Ingress Controller for Redis Enterprise

Traditional Kubernetes Ingress configuration for exposing Redis Enterprise Cluster UI and databases.

## 📋 Overview

This configuration uses the NGINX Ingress Controller to provide external access to:
- **REC UI** (port 8443) - HTTPS with TLS termination
- **Redis Databases** (port 12000+) - TCP with TLS passthrough

## 📖 How It Works

NGINX Ingress handles **two different types of traffic**:

### 1. **HTTP/HTTPS Traffic (REC UI)** ✅ Uses Ingress Resource
- Protocol: HTTP/HTTPS
- Configuration: Kubernetes `Ingress` resource
- File: `01-ingress-rec-ui.yaml`
- Routing: Based on hostname (`rec-ui.example.com`)
- Port: 443 (HTTPS)

### 2. **Database Traffic** - Two Methods Available

#### **Method A: Ingress Resource with SNI** (Recommended for Production)
- Protocol: TLS over TCP
- Configuration: Kubernetes `Ingress` resource with `ssl-passthrough`
- File: `02-ingress-database.yaml`
- Routing: Based on **hostname (SNI)** (`redis-12000.example.com`)
- Port: **443** (all databases share this port)
- **Advantages:**
  - ✅ All databases on standard port 443
  - ✅ Easier firewall rules
  - ✅ More flexible routing
  - ✅ Follows official Redis documentation
- **Requirements:**
  - DNS configuration required
  - Client MUST support SNI

#### **Method B: TCP Passthrough via Helm** (Simpler Alternative)
- Protocol: TCP (raw Redis protocol)
- Configuration: Helm values (`--set tcp.PORT=...`)
- File: **NONE** (configured via Helm)
- Routing: Based on **port** (12000, 12001, etc.)
- Ports: Dedicated port per database
- **Advantages:**
  - ✅ Simpler setup (no DNS needed)
  - ✅ No SNI requirement
  - ✅ Direct port mapping
- **Disadvantages:**
  - ❌ Requires dedicated port per database
  - ❌ More firewall rules needed

**🔑 Key Difference:**
- **Method A (Ingress)**: All databases → port 443, routed by hostname
- **Method B (TCP)**: Each database → dedicated port (12000, 12001, etc.)

**What Helm does automatically for databases:**

When you run:
```bash
helm install ingress-nginx ... --set tcp.12000="redis-enterprise/test-db:10414"
```

Helm automatically creates:

1. **ConfigMap** `tcp-services`:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: tcp-services
     namespace: ingress-nginx
   data:
     "12000": "redis-enterprise/test-db:10414"
   ```

2. **Updates LoadBalancer Service** to expose port 12000:
   ```yaml
   ports:
     - port: 12000
       targetPort: 12000
       protocol: TCP
   ```

3. **Configures NGINX** to proxy TCP traffic from port 12000 to the database service

**You don't need to create any YAML files for databases!**

## 🏗️ Architecture

```
                                    ┌─────────────────────────────────────┐
                                    │   NGINX Ingress Controller          │
                                    │   (LoadBalancer Service)            │
                                    │   Ports: 80, 443, 12000, 12001...   │
                                    └──────────┬──────────────────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
            ┌───────▼────────┐        ┌────────▼────────┐       ┌────────▼────────┐
            │ Ingress YAML   │        │ Helm tcp.12000  │       │ Helm tcp.12001  │
            │ (rec-ui)       │        │ (auto ConfigMap)│       │ (auto ConfigMap)│
            │ HTTPS (443)    │        │ TCP (12000)     │       │ TCP (12001)     │
            └───────┬────────┘        └────────┬────────┘       └────────┬────────┘
                    │                          │                          │
            ┌───────▼────────┐        ┌────────▼────────┐       ┌────────▼────────┐
            │  REC Service   │        │  DB Service     │       │  DB Service     │
            │  rec-ui:8443   │        │  test-db:10414  │       │  cache-db:11234 │
            └────────────────┘        └─────────────────┘       └─────────────────┘

Legend:
  • REC UI: Uses Ingress resource (01-ingress-rec-ui.yaml)
  • Databases: Use Helm values (--set tcp.PORT="namespace/service:port")
  • Note: External port (12000) can differ from internal port (10414)
```

## 📁 Files

```
nginx/
├── README.md                          # This file
├── 01-ingress-rec-ui.yaml             # REC UI Ingress (HTTPS)
└── 02-ingress-database.yaml           # Database Ingress (TLS passthrough, SNI-based)
```

**Files Explained:**
- **01-ingress-rec-ui.yaml**: REC UI access via HTTPS (hostname-based routing)
- **02-ingress-database.yaml**: Database access via TLS passthrough (SNI-based routing)
  - **Optional**: Use this for production with proper DNS
  - **Alternative**: Use TCP passthrough via Helm (simpler, no DNS needed)

## 🚀 Installation

### Step 1: Install NGINX Ingress Controller with SSL Passthrough

**⚠️ IMPORTANT:** For Redis Enterprise Active-Active, you MUST enable SSL passthrough!

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install for AWS EKS
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"

# For GKE
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true

# For AKS
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true

# For vanilla Kubernetes
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true
```

**Important Notes:**
- `--set controller.extraArgs.enable-ssl-passthrough=true` is **REQUIRED** for Redis Enterprise Active-Active
- Without SSL passthrough, RERC (Remote Cluster) connections will fail with HTTP 502 errors
- For single-cluster deployments (non-Active-Active), SSL passthrough is optional

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

### Step 3: Deploy Ingress Resources

#### REC UI (Required)

```bash
# Apply REC UI Ingress
kubectl apply -f 01-ingress-rec-ui.yaml
```

**Note:** Update the hostname in `01-ingress-rec-ui.yaml` before applying if needed.

#### Databases (Choose One Method)

**Method A: Ingress Resource (Recommended for Production)**

```bash
# Apply Database Ingress
kubectl apply -f 02-ingress-database.yaml
```

**Prerequisites:**
- DNS configured: `redis-12000.example.com` → LoadBalancer IP
- Database created with `tlsMode: enabled`
- Update hostnames in `02-ingress-database.yaml`

**Advantages:**
- All databases on port 443
- Easier firewall rules
- Follows official Redis documentation

**Method B: TCP Passthrough via Helm (Simpler Alternative)**

Configure during Helm install/upgrade (see Step 1 above):

```bash
--set tcp.12000="redis-enterprise/test-db:12000"
```

**Advantages:**
- Simpler setup (no DNS needed)
- No SNI requirement
- Direct port mapping

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

### Database Ingress (02-ingress-database.yaml) - Method A

Exposes databases via TLS passthrough with SNI-based routing.

**Key configurations:**
- `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` - **REQUIRED** for Redis databases
- `ingressClassName: nginx` - Uses NGINX Ingress Controller
- Routing: Based on hostname (SNI)
- Port: 443 (all databases share this port)

**Update before applying:**
```yaml
rules:
  - host: redis-12000.example.com  # ⚠️ Change to your domain
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: test-db        # ⚠️ Change to your database service name
              port:
                number: 12000      # ⚠️ Change to your database port
```

**How it works:**
1. Client connects to `redis-12000.example.com:443` with SNI
2. NGINX reads SNI header and routes to `test-db:12000`
3. Database handles TLS termination
4. All databases use port 443 (easier firewall rules)

**Testing:**
```bash
# Get database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Test with redis-cli (note: port 443, not 12000!)
redis-cli -h redis-12000.example.com -p 443 \
  --tls --insecure \
  --sni redis-12000.example.com \
  -a ${DB_PASS} \
  PING
```

### TCP Passthrough (Configured via Helm) - Method B

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

## 🔀 Database Access Methods Comparison

| Aspect | Method A: Ingress Resource | Method B: TCP Passthrough |
|--------|----------------------------|---------------------------|
| **Configuration** | Kubernetes Ingress YAML | Helm values |
| **File** | `02-ingress-database.yaml` | None (Helm only) |
| **Routing** | Hostname-based (SNI) | Port-based |
| **External Port** | 443 (all databases) | Dedicated per DB (12000, 12001, etc.) |
| **DNS Required** | ✅ Yes | ❌ No |
| **SNI Required** | ✅ Yes (client must support) | ❌ No |
| **Firewall Rules** | Simple (only port 443) | Complex (one rule per DB) |
| **Setup Complexity** | Medium | Low |
| **Flexibility** | High (hostname routing) | Low (port routing) |
| **Official Docs** | ✅ Recommended | Alternative |
| **Best For** | Production with DNS | Dev/Test, no DNS |

**Recommendation:**
- **Production**: Use Method A (Ingress Resource) with proper DNS
- **Dev/Test**: Use Method B (TCP Passthrough) for simplicity

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

#### Method A: Via Ingress Resource (SNI-based)

```bash
# Get database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Test database connection via hostname (port 443)
redis-cli -h redis-12000.example.com \
  -p 443 \
  --tls \
  --insecure \
  --sni redis-12000.example.com \
  -a ${DB_PASS} \
  PING
```

**Expected:** `PONG`

**Note:**
- Uses port 443 (standard HTTPS port)
- Requires SNI support in client
- Requires DNS configuration

#### Method B: Via TCP Passthrough (Port-based)

```bash
# Get database password
DB_PASS=$(kubectl get secret redb-test-db -n redis-enterprise \
  -o jsonpath='{.data.password}' | base64 -d)

# Test database connection via TCP port 12000
redis-cli -h ${LB_HOST} \
  -p 12000 \
  --tls \
  --insecure \
  -a ${DB_PASS} \
  PING
```

**Expected:** `PONG`

**Note:**
- Uses dedicated port (12000)
- No SNI required
- No DNS required (can use LoadBalancer IP directly)

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

