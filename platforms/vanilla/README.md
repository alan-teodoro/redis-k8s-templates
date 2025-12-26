# Redis Enterprise on Vanilla Kubernetes

Redis Enterprise deployment guide for vanilla (upstream) Kubernetes.

---

## Overview

Deployment guide for vanilla Kubernetes (upstream, non-cloud-managed).

**Requirements:**
- Kubernetes 1.23+
- Storage class available (local-path, NFS, Ceph, etc.)
- LoadBalancer or Ingress controller for external access

---

## Directory Structure

```
platforms/vanilla/
└── README.md           # This file
```

**Generic configurations** (used by all platforms including vanilla):
- **Operator:** [../../operator/README.md](../../operator/README.md)
- **Deployments:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)
- **Networking:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)
- **Monitoring:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)
- **Security:** [../../security/README.md](../../security/README.md)

---

## Quick Start

### Prerequisites

- Kubernetes cluster (1.23+)
- `kubectl` configured
- `helm` v3.x installed
- Storage class available (check with `kubectl get storageclass`)

### Installation Steps

#### 1. Verify Storage (Platform-Specific)

Ensure you have a storage class available:

```bash
# Check available storage classes
kubectl get storageclass

# If no storage class exists, install one (example: local-path-provisioner)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set as default (if needed)
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

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

## Vanilla Kubernetes Considerations

### Storage

Vanilla Kubernetes does not include a default storage provisioner. You must install one:

**Options:**
- **local-path-provisioner** (Rancher) - Simple, local storage
- **NFS provisioner** - Network file system
- **Ceph/Rook** - Distributed storage
- **Longhorn** - Cloud-native distributed storage

**Recommendation:** For production, use distributed storage (Ceph, Longhorn).

### Networking

Vanilla Kubernetes does not include a LoadBalancer implementation. You must install one:

**Options:**
- **MetalLB** - Bare metal load balancer
- **Gateway API** - Modern networking API (recommended)
- **Ingress Controller** - NGINX, Traefik, HAProxy

**Recommendation:** Use Gateway API with NGINX Gateway Fabric.

### Multi-Zone Deployment

If your cluster spans multiple zones/racks, ensure nodes are labeled with `topology.kubernetes.io/zone`.

Redis Enterprise will automatically distribute pods when rack awareness is enabled (already configured in generic deployment).

---

## Troubleshooting

### No Storage Class Available

```bash
# Check storage classes
kubectl get storageclass

# Install local-path-provisioner (for testing)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n redis-enterprise

# Check events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'

# Check if storage class exists
kubectl get storageclass
```

### LoadBalancer Service Stuck in Pending

Vanilla Kubernetes does not include a LoadBalancer implementation.

**Solutions:**
- Install MetalLB: https://metallb.universe.tf/
- Use NodePort instead of LoadBalancer
- Use Ingress/Gateway API

---

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [MetalLB](https://metallb.universe.tf/)
- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)

