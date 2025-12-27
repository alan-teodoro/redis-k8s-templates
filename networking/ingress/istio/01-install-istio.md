# Istio Installation Guide

Complete guide to install Istio service mesh for Redis Enterprise external routing.

---

## 📋 Prerequisites

- Kubernetes 1.23+ or OpenShift 4.10+
- kubectl or oc CLI configured with cluster admin access
- Minimum 4 vCPUs and 8GB RAM available in cluster
- Helm v3.x (optional, for Helm-based installation)

---

## 🚀 Installation Methods

### Method 1: Using istioctl (Recommended)

#### Step 1: Download istioctl

```bash
# Download latest Istio
curl -L https://istio.io/downloadIstio | sh -

# Or download specific version
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.0 sh -

# Move to Istio directory
cd istio-1.24.0

# Add istioctl to PATH
export PATH=$PWD/bin:$PATH
```

#### Step 2: Verify istioctl

```bash
istioctl version

# Expected output:
# no running Istio pods in "istio-system"
# 1.24.0
```

#### Step 3: Install Istio

```bash
# Install with default profile
istioctl install --set profile=default -y

# Or install with demo profile (for testing)
# istioctl install --set profile=demo -y
```

**Profiles:**
- `default`: Production-ready configuration (recommended)
- `demo`: For testing and learning (includes more components)
- `minimal`: Minimal components
- `production`: High availability configuration

#### Step 4: Verify Installation

```bash
# Check Istio pods
kubectl get pods -n istio-system

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# istio-ingressgateway-xxx                1/1     Running   0          2m
# istiod-xxx                              1/1     Running   0          2m
```

#### Step 5: Get Ingress Gateway External IP

```bash
kubectl get svc istio-ingressgateway -n istio-system

# Expected output:
# NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# istio-ingressgateway   LoadBalancer   10.34.67.89    <EXTERNAL_IP>    15021:...,80:...,443:...
```

**Note:** On cloud providers (AWS, GCP, Azure), `EXTERNAL-IP` will be automatically assigned. On bare-metal, you may need to configure MetalLB or use NodePort.

---

### Method 2: Using Helm

#### Step 1: Add Istio Helm Repository

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

#### Step 2: Create Namespace

```bash
kubectl create namespace istio-system
```

#### Step 3: Install Istio Base

```bash
helm install istio-base istio/base \
  --namespace istio-system \
  --wait
```

#### Step 4: Install Istiod (Control Plane)

```bash
helm install istiod istio/istiod \
  --namespace istio-system \
  --wait
```

#### Step 5: Install Istio Ingress Gateway

```bash
helm install istio-ingressgateway istio/gateway \
  --namespace istio-system \
  --wait
```

#### Step 6: Verify Installation

```bash
kubectl get pods -n istio-system
kubectl get svc istio-ingressgateway -n istio-system
```

---

## 🔧 Configuration for Redis Enterprise

### Enable Sidecar Injection (Optional)

If you want Istio to manage traffic between Redis Enterprise pods:

```bash
# Label namespace for automatic sidecar injection
kubectl label namespace redis-enterprise istio-injection=enabled

# Verify label
kubectl get namespace redis-enterprise --show-labels
```

**Note:** Sidecar injection is **optional** for Redis Enterprise. The ingress gateway works without it.

### Configure Istio for TLS Passthrough

TLS passthrough is required for Redis databases. This is configured in the Gateway resource (see `02-gateway.yaml`).

No additional Istio configuration is needed - passthrough is enabled per-Gateway.

---

## ✅ Verification

### Check Istio Components

```bash
# Check all Istio resources
kubectl get all -n istio-system

# Check Istio configuration
istioctl analyze -n istio-system
```

### Test Istio Ingress Gateway

```bash
# Get external IP
ISTIO_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Istio Ingress Gateway IP: $ISTIO_IP"

# Test connectivity (should return 404 - no routes configured yet)
curl -I http://$ISTIO_IP
```

---

## 🎯 Next Steps

1. **Configure DNS**: Create wildcard DNS record `*.redis.example.com` → Istio LoadBalancer IP

2. **Deploy Gateway**: Apply `02-gateway.yaml`

3. **Deploy VirtualServices**: Apply `03-virtualservice-rec.yaml` and `04-virtualservice-db.yaml`

4. **Deploy REC**: Apply `05-rec-istio.yaml`

---

## 🔍 Troubleshooting

### Istio Pods Not Starting

**Check events:**
```bash
kubectl describe pod <pod-name> -n istio-system
```

**Common issues:**
- Insufficient resources (increase node capacity)
- Image pull errors (check network connectivity)

### LoadBalancer Pending

**Symptoms:** `EXTERNAL-IP` shows `<pending>`

**Causes:**
- Cloud provider LoadBalancer not configured
- Bare-metal cluster without MetalLB

**Solutions:**

**For AWS EKS:**
```bash
# Verify AWS Load Balancer Controller is installed
kubectl get deployment -n kube-system aws-load-balancer-controller
```

**For bare-metal (use NodePort):**
```bash
# Change service type to NodePort
kubectl patch svc istio-ingressgateway -n istio-system \
  -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get svc istio-ingressgateway -n istio-system
```

### Istio Version Mismatch

**Check versions:**
```bash
istioctl version
```

**Upgrade Istio:**
```bash
istioctl upgrade --set profile=default
```

---

## 🗑️ Uninstallation

### Using istioctl

```bash
# Uninstall Istio
istioctl uninstall --purge -y

# Delete namespace
kubectl delete namespace istio-system
```

### Using Helm

```bash
# Uninstall in reverse order
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

# Delete namespace
kubectl delete namespace istio-system
```

---

## 📚 Additional Resources

- [Istio Getting Started](https://istio.io/latest/docs/setup/getting-started/)
- [Istio Installation Profiles](https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
- [Istio on AWS EKS](https://istio.io/latest/docs/setup/platform-setup/amazon-eks/)
- [Istio on GKE](https://istio.io/latest/docs/setup/platform-setup/gke/)
- [Istio on AKS](https://istio.io/latest/docs/setup/platform-setup/azure/)

