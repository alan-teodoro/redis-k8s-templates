# Redis Enterprise on Google GKE

Redis Enterprise deployment guide for Google Kubernetes Engine (GKE).

---

## Overview

GKE-specific configurations and guides for deploying Redis Enterprise.

**Key GKE-Specific Requirements:**
- **GCE Persistent Disk CSI Driver** (default in GKE 1.18+)
- **Storage Classes** (pd-ssd or pd-balanced recommended)
- **Workload Identity** (optional, for secrets management)

---

## Directory Structure

```
platforms/gke/
├── README.md           # This file
├── storage/            # GCE PD storage classes (GKE-specific)
│   ├── README.md
│   ├── pd-ssd-storageclass.yaml
│   └── pd-balanced-storageclass.yaml
└── workload-identity/  # Workload Identity for GKE (GKE-specific, optional)
    └── README.md
```

**Generic configurations** (used by all platforms including GKE):
- **Operator:** [../../operator/README.md](../../operator/README.md)
- **Deployments:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)
- **Networking:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)
- **Monitoring:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)
- **Security:** [../../security/README.md](../../security/README.md)

---

## Quick Start

### Prerequisites

- GKE cluster (1.23+)
- `kubectl` configured
- `helm` v3.x installed
- GCE Persistent Disk CSI driver (default in GKE 1.18+)

### Installation Steps

#### 1. Configure Storage (GKE-Specific)

**See:** [storage/README.md](storage/README.md)

**Status:** 🚧 Coming soon

Recommended: Use `pd-ssd` or `pd-balanced` storage class.

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

# Create secrets
kubectl apply -f ../../deployments/single-region/01-rec-admin-secret.yaml
kubectl apply -f ../../deployments/single-region/02-redb-secret.yaml

# Apply RBAC
kubectl apply -f ../../deployments/single-region/03-rbac-rack-awareness.yaml

# Deploy REC
kubectl apply -f ../../deployments/single-region/04-rec.yaml

# Wait for ready
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# Create database (port 12000)
kubectl apply -f ../../deployments/single-region/05-redb.yaml
```

#### 4. Configure Networking (Generic)

**See:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)

Recommended: Gateway API with NGINX Gateway Fabric

**Alternative:** [../../networking/ingress/nginx-ingress/README.md](../../networking/ingress/nginx-ingress/README.md)

#### 5. Setup Monitoring (Generic, Optional)

**See:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

---

## GKE-Specific Features

### Storage Options

**pd-ssd (Recommended for Production):**
- ✅ High performance SSD
- ✅ Low latency
- ✅ Production workloads

**pd-balanced (Recommended for Dev/Test):**
- ✅ Balanced performance/cost
- ✅ Good for most workloads

**See:** [storage/README.md](storage/README.md)

**Status:** 🚧 Coming soon

### Workload Identity

Optional: Use Workload Identity for secrets management integration.

**See:** [workload-identity/README.md](workload-identity/README.md)

**Status:** 🚧 Coming soon

### Multi-Zone Deployment

GKE supports multi-zone deployments. Redis Enterprise automatically distributes pods across zones when rack awareness is enabled (already configured in generic deployment).

---

## Troubleshooting

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

- [Google GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GCE Persistent Disk CSI Driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver)
- [GKE Storage Classes](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes)
- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)

