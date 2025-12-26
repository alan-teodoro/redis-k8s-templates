# Redis Enterprise on Amazon EKS

Redis Enterprise deployment guide for Amazon Elastic Kubernetes Service (EKS).

---

## Overview

EKS-specific configurations and guides for deploying Redis Enterprise.

**Key EKS-Specific Requirements:**
- **EBS CSI Driver** for persistent storage
- **Storage Classes** (gp3 recommended)
- **IAM Roles** (optional, for secrets management)

---

## Directory Structure

```
platforms/eks/
├── README.md           # This file
├── storage/            # EBS storage classes (EKS-specific)
│   ├── README.md
│   ├── gp3-storageclass.yaml
│   └── io2-storageclass.yaml
└── iam/                # IAM roles for IRSA (EKS-specific, optional)
    └── README.md
```

**Generic configurations** (used by all platforms including EKS):
- **Operator:** [../../operator/README.md](../../operator/README.md)
- **Deployments:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)
- **Networking:** [../../networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)
- **Monitoring:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)
- **Security:** [../../security/README.md](../../security/README.md)

---

## Quick Start

### Prerequisites

- EKS cluster (1.23+)
- `kubectl` configured
- `helm` v3.x installed
- EBS CSI driver installed (default in EKS 1.23+)

### Installation Steps

#### 1. Configure Storage (EKS-Specific)

**See:** [storage/README.md](storage/README.md)

```bash
# Apply gp3 storage class
kubectl apply -f storage/gp3-storageclass.yaml

# Set as default
kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove default from gp2 (if exists)
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
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

## EKS-Specific Features

### Storage Options

**gp3 (Recommended):**
- ✅ Better performance (3000 IOPS baseline)
- ✅ Lower cost than gp2
- ✅ `WaitForFirstConsumer` binding mode

**io2 (High Performance):**
- ✅ High IOPS (up to 64,000)
- ✅ Low latency
- ✅ Production workloads

**See:** [storage/README.md](storage/README.md)

### IAM Roles for Service Accounts (IRSA)

Optional: Use IRSA for secrets management integration.

**See:** [iam/README.md](iam/README.md)

**Status:** 🚧 Coming soon

### Multi-AZ Deployment

EKS supports multi-AZ deployments. Redis Enterprise automatically distributes pods across availability zones when rack awareness is enabled (already configured in generic deployment).

---

## Troubleshooting

### EBS CSI Driver Not Installed

```bash
# Check if CSI driver is running
kubectl get pods -n kube-system | grep ebs-csi

# If not installed, install it
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver -n kube-system
```

### Storage Class Issues

```bash
# Check storage classes
kubectl get storageclass

# Check if gp3 is default
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

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [EBS Volume Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html)
- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)

