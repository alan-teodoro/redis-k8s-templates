# Quick Start Guide

This guide provides the **correct sequence** for deploying Redis Enterprise on Kubernetes.

Each section references detailed documentation for more information.

---

## Prerequisites

- ✅ Kubernetes cluster running (EKS, GKE, AKS, or on-premises)
- ✅ `kubectl` configured and connected to cluster
- ✅ `helm` installed (v3.x)
- ✅ Cluster admin permissions

---

## Installation Order

### 1. Storage Configuration (5 min) 📦

**For EKS:**

See: [platforms/eks/storage/README.md](platforms/eks/storage/README.md)

```bash
# Apply gp3 StorageClass
kubectl apply -f platforms/eks/storage/gp3-storageclass.yaml

# Set as default
kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify
kubectl get storageclass
```

**For other platforms:** Check `platforms/<your-platform>/storage/`

---

### 2. Redis Enterprise Operator (10 min) 🔧

See: [operator/installation/helm/README.md](operator/installation/helm/README.md)

```bash
# Create namespace
kubectl create namespace redis-enterprise

# Add Helm repo
helm repo add redis https://helm.redis.io
helm repo update

# Install operator
helm install redis-operator redis/redis-enterprise-operator --version 8.0.6-8 -n redis-enterprise

# Apply RBAC for rack awareness (multi-AZ)
kubectl apply -f examples/basic-deployment/rbac-rack-awareness.yaml

# Verify operator is running
kubectl get pods -n redis-enterprise
```

---

### 3. Redis Enterprise Cluster (15 min) 🗄️

See: [deployments/basic/README.md](deployments/basic/README.md)

```bash
# Deploy REC (3 nodes)
kubectl apply -f examples/basic-deployment/rec-basic.yaml

# Wait for cluster to be ready (5-10 min)
kubectl wait --for=condition=ready rec/rec -n redis-enterprise --timeout=600s

# Verify cluster status
kubectl get rec -n redis-enterprise
kubectl describe rec rec -n redis-enterprise

# Get admin password
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
echo
```

---

### 4. Test Database (5 min) 💾

See: [deployments/basic/README.md](deployments/basic/README.md)

```bash
# Create test database
kubectl apply -f examples/basic-deployment/redb-test.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready redb/test-db -n redis-enterprise --timeout=300s

# Verify database
kubectl get redb test-db -n redis-enterprise

# Test connectivity
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 11909 PING
```

---

### 5. Monitoring (Optional - 15 min) 📊

See: [monitoring/prometheus/README.md](monitoring/prometheus/README.md)

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f monitoring/prometheus/values.yaml

# Apply ServiceMonitor for Redis Enterprise
kubectl apply -f monitoring/prometheus/servicemonitors/redis-enterprise.yaml

# Apply PrometheusRules (alerts)
kubectl apply -f monitoring/prometheus/prometheusrules/redis-enterprise-alerts.yaml

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials: admin / prom-operator
# Import dashboard: monitoring/grafana/dashboards/redis-enterprise-overview.json
```

---

### 6. Admission Controller (Optional - 5 min) ✅

See: [operator/configuration/admission-controller/README.md](operator/configuration/admission-controller/README.md)

```bash
# Apply admission controller webhook
kubectl apply -f operator/configuration/admission-controller/webhook.yaml

# Verify
kubectl get validatingwebhookconfiguration redb-admission
```

---

### 7. Networking - Gateway API (Optional - 20 min) 🌐

See: [networking/gateway-api/nginx-gateway-fabric/README.md](networking/gateway-api/nginx-gateway-fabric/README.md)

```bash
# Install Gateway API CRDs (Experimental Channel - includes TLSRoute for database access)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f -

# Install NGINX Gateway Fabric with experimental features enabled
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  -n nginx-gateway \
  --create-namespace \
  --set nginxGateway.gwAPIExperimentalFeatures.enable=true

# Create TLS certificate (self-signed for testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.redis.example.com/O=Redis"
kubectl create secret tls redis-tls-cert \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n nginx-gateway
rm /tmp/tls.key /tmp/tls.crt

# Create Gateway
kubectl apply -f networking/gateway-api/nginx-gateway-fabric/gateway.yaml

# Extract backend CA certificate
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  openssl s_client -connect rec-ui.redis-enterprise.svc.cluster.local:8443 -showcerts </dev/null 2>/dev/null | \
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > rec-ui-cert.pem

# Create ConfigMap with CA
kubectl create configmap rec-backend-ca-cert \
  --from-file=ca.crt=rec-ui-cert.pem \
  -n redis-enterprise

# Apply BackendTLSPolicy
kubectl apply -f networking/gateway-api/nginx-gateway-fabric/backend-tls-policy.yaml

# Apply HTTPRoute for REC UI
kubectl apply -f networking/gateway-api/nginx-gateway-fabric/httproute-rec-ui.yaml

# Get Gateway IP and test
GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
echo "Gateway Hostname: $GATEWAY_HOSTNAME"

GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)
echo "Gateway IP: $GATEWAY_IP"

curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
```

# Add host entry to /etc/hosts
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts

# Open browser
open https://ui.redis.example.com

# (Optional) Database access via TLSRoute
kubectl apply -f networking/gateway-api/nginx-gateway-fabric/tlsroute-database.yaml

---

## Verification Commands

```bash
# Check all Redis Enterprise resources
kubectl get rec,redb -n redis-enterprise

# Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50

# Check cluster status
kubectl describe rec rec -n redis-enterprise

# Check database status
kubectl describe redb test-db -n redis-enterprise

# Check services
kubectl get svc -n redis-enterprise
```

---

## Next Steps

- **Production Setup**: See [deployments/production/](deployments/production/)
- **Security**: See [security/](security/)
- **Backup/Restore**: See [backup-restore/](backup-restore/)
- **Active-Active**: See [deployments/active-active/](deployments/active-active/)

---

## Troubleshooting

See individual component READMEs for detailed troubleshooting:
- [Operator Troubleshooting](operator/installation/helm/README.md#troubleshooting)
- [Deployment Troubleshooting](deployments/basic/README.md#troubleshooting)
- [Monitoring Troubleshooting](monitoring/prometheus/README.md#troubleshooting)
- [Networking Troubleshooting](networking/gateway-api/nginx-gateway-fabric/README.md#troubleshooting)

