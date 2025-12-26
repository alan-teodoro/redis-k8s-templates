# Redis Enterprise on Azure AKS

Redis Enterprise deployment guide for Azure Kubernetes Service (AKS).

---

## Overview

AKS-specific configurations and guides for deploying Redis Enterprise.

**Key AKS-Specific Requirements:**
- **Azure Disk CSI Driver** (default in AKS 1.21+)
- **Storage Classes** (managed-csi-premium or managed-csi recommended)
- **Managed Identity** (optional, for secrets management)

---

## Directory Structure

```
platforms/aks/
├── README.md           # This file
├── storage/            # Azure Disk storage classes (AKS-specific)
│   ├── README.md
│   ├── managed-csi-premium-storageclass.yaml
│   └── managed-csi-storageclass.yaml
└── managed-identity/   # Managed Identity for AKS (AKS-specific, optional)
    └── README.md
```

**Generic configurations** (used by all platforms including AKS):
- **Operator:** [../../operator/README.md](../../operator/README.md)
- **Deployments:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)
- **Networking:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)
- **Monitoring:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)
- **Security:** [../../security/README.md](../../security/README.md)

---

## Quick Start

### Prerequisites

- AKS cluster (1.23+)
- `kubectl` configured
- `helm` v3.x installed
- Azure Disk CSI driver (default in AKS 1.21+)

### Installation Steps

#### 1. Configure Storage (AKS-Specific)

**See:** [storage/README.md](storage/README.md)

**Status:** 🚧 Coming soon

Recommended: Use `managed-csi-premium` or `managed-csi` storage class.

#### 2. Install Operator (Generic)

**See:** [../../operator/README.md](../../operator/README.md)

```bash
helm repo add redis https://helm.redis.io
helm install redis-operator redis/redis-enterprise-operator \
  --version 8.0.6-8 \
  -n redis-enterprise \
  --create-namespace
```

#### 3. Deploy Cluster & Database (Generic)

**See:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)

```bash
# Create namespace
kubectl apply -f ../../deployments/single-region/00-namespace.yaml

# Apply RBAC
kubectl apply -f ../../deployments/single-region/01-rbac-rack-awareness.yaml

# Deploy REC
kubectl apply -f ../../deployments/single-region/02-rec.yaml

# Wait for ready
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# Create database
kubectl apply -f ../../deployments/single-region/03-redb.yaml
```

#### 4. Configure Networking (Generic)

**See:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)

Recommended: Gateway API with NGINX Gateway Fabric

**Alternative:** [../../networking/ingress/nginx-ingress/README.md](../../networking/ingress/nginx-ingress/README.md)

#### 5. Setup Monitoring (Generic, Optional)

**See:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

---

## AKS-Specific Features

### Storage Options

**managed-csi-premium (Recommended for Production):**
- ✅ Premium SSD
- ✅ High performance
- ✅ Production workloads

**managed-csi (Recommended for Dev/Test):**
- ✅ Standard SSD
- ✅ Balanced performance/cost

**See:** [storage/README.md](storage/README.md)

**Status:** 🚧 Coming soon

### Managed Identity

Optional: Use Managed Identity for secrets management integration.

**See:** [managed-identity/README.md](managed-identity/README.md)

**Status:** 🚧 Coming soon

### Multi-Zone Deployment

AKS supports multi-zone deployments. Redis Enterprise automatically distributes pods across zones when rack awareness is enabled (already configured in generic deployment).

---

## Troubleshooting

### Azure Disk CSI Driver Not Installed

```bash
# Check if CSI driver is running
kubectl get pods -n kube-system | grep csi-azuredisk

# If not installed, enable it
az aks update --name <cluster-name> --resource-group <resource-group> --enable-disk-driver
```

### Storage Class Issues

```bash
# Check storage classes
kubectl get storageclass

# Check default storage class
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n redis-enterprise

# Check events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'
```

---

## References

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Disk CSI Driver](https://docs.microsoft.com/en-us/azure/aks/azure-disk-csi)
- [AKS Storage Classes](https://docs.microsoft.com/en-us/azure/aks/concepts-storage)
- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)

