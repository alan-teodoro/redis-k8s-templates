# Istio Service Mesh for Redis Enterprise

Advanced service mesh configuration for Redis Enterprise with Istio.

## 📋 Overview

Istio provides:
- **Advanced traffic management** (routing, retries, timeouts)
- **Built-in observability** (metrics, traces, logs)
- **mTLS** between services
- **Circuit breaking** and fault injection
- **Gateway** for external access

## 🏗️ Architecture

```
┌─────────────────────────────┐
│     Istio Ingress Gateway   │
│    (LoadBalancer Service)   │
└──────────┬──────────────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼────┐   ┌───▼────┐
│Gateway │   │Gateway │
│  (UI)  │   │  (DB)  │
└───┬────┘   └───┬────┘
    │            │
┌───▼────┐   ┌───▼────┐
│VirtualS│   │VirtualS│
│ervice  │   │ervice  │
└───┬────┘   └───┬────┘
    │            │
┌───▼────┐   ┌───▼────┐
│ REC UI │   │   DB   │
│  :8443 │   │ :12000 │
└────────┘   └────────┘
```

## 📁 Files

```
istio/
├── README.md                          # This file
├── 00-install-istio.sh                # Installation script
├── 01-gateway-rec-ui.yaml             # Gateway for REC UI
├── 02-virtualservice-rec-ui.yaml      # VirtualService for REC UI
├── 03-gateway-database.yaml           # Gateway for databases
└── 04-virtualservice-database.yaml    # VirtualService for databases
```

## 🚀 Installation

### Step 1: Install Istio

```bash
# Run installation script
./00-install-istio.sh

# Or manually:
# Download istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set profile=default -y

# Enable sidecar injection for redis-enterprise namespace
kubectl label namespace redis-enterprise istio-injection=enabled
```

### Step 2: Wait for Istio

```bash
kubectl wait --for=condition=ready pod \
  -l app=istiod \
  -n istio-system \
  --timeout=300s

# Get Ingress Gateway IP/hostname
kubectl get svc istio-ingressgateway -n istio-system
```

### Step 3: Configure DNS

```
rec-ui.example.com → <INGRESS-GATEWAY-IP>
db-test.example.com → <INGRESS-GATEWAY-IP>
```

### Step 4: Deploy Istio Resources

```bash
# Update hostnames in YAML files
kubectl apply -f 01-gateway-rec-ui.yaml
kubectl apply -f 02-virtualservice-rec-ui.yaml
kubectl apply -f 03-gateway-database.yaml
kubectl apply -f 04-virtualservice-database.yaml
```

## 📝 Configuration Files

### 01-gateway-rec-ui.yaml

Istio Gateway for REC UI (HTTPS).

**Features:**
- TLS termination
- HTTPS (port 443)

### 02-virtualservice-rec-ui.yaml

Routes traffic from Gateway to REC UI service.

**Features:**
- HTTP routing
- Timeout configuration
- Retry policy

### 03-gateway-database.yaml

Istio Gateway for databases (TLS passthrough).

**Features:**
- TLS passthrough
- SNI-based routing
- Multiple database support

### 04-virtualservice-database.yaml

Routes traffic from Gateway to database services.

**Features:**
- TLS routing
- SNI matching
- Per-database routing

## 🔐 Access

### REC UI

```bash
GATEWAY_HOST=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "REC UI: https://${GATEWAY_HOST}"
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

## 🔧 Advanced Features

### Traffic Splitting (Canary Deployment)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: rec-ui-canary
spec:
  hosts:
    - rec-ui.example.com
  http:
    - match:
        - headers:
            x-version:
              exact: "v2"
      route:
        - destination:
            host: rec-ui-v2
    - route:
        - destination:
            host: rec-ui
          weight: 90
        - destination:
            host: rec-ui-v2
          weight: 10
```

### Circuit Breaking

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: rec-ui-circuit-breaker
spec:
  host: rec-ui
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

### Fault Injection

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: rec-ui-fault
spec:
  hosts:
    - rec-ui
  http:
    - fault:
        delay:
          percentage:
            value: 10
          fixedDelay: 5s
      route:
        - destination:
            host: rec-ui
```

## 🔍 Troubleshooting

### Check Istio Status

```bash
istioctl analyze -n redis-enterprise
```

### Check Gateway Status

```bash
kubectl get gateway -n redis-enterprise
kubectl describe gateway rec-ui-gateway -n redis-enterprise
```

### Check VirtualService

```bash
kubectl get virtualservice -n redis-enterprise
kubectl describe virtualservice rec-ui -n redis-enterprise
```

### View Istio Logs

```bash
kubectl logs -n istio-system -l app=istio-ingressgateway --tail=50
```

## 🧹 Cleanup

```bash
kubectl delete -f 01-gateway-rec-ui.yaml
kubectl delete -f 02-virtualservice-rec-ui.yaml
kubectl delete -f 03-gateway-database.yaml
kubectl delete -f 04-virtualservice-database.yaml

istioctl uninstall --purge -y
kubectl delete namespace istio-system
```

## 📚 Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Security](https://istio.io/latest/docs/concepts/security/)
- [Observability](https://istio.io/latest/docs/concepts/observability/)

