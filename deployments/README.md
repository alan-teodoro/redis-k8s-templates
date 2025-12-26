# Redis Enterprise Deployments

Generic deployment configurations for Redis Enterprise on Kubernetes.

**Platform-agnostic:** Works on EKS, GKE, AKS, OpenShift, and vanilla Kubernetes.

---

## Deployment Patterns

### 1. Single-Region (Basic)

**See:** [single-region/README.md](single-region/README.md)

Standard Redis Enterprise deployment in a single Kubernetes cluster.

**Use cases:**
- Development and testing
- Single data center deployments
- Applications requiring high availability within a single region

**Features:**
- 3-node Redis Enterprise Cluster
- High availability (rack awareness)
- Automatic failover
- Replication

---

### 2. Active-Active (Multi-Region)

**See:** [active-active/README.md](active-active/README.md)

Active-Active deployment across two Kubernetes clusters for geo-distribution.

**Use cases:**
- Multi-region deployments
- Global applications requiring low latency
- Disaster recovery with active-active replication
- Applications requiring local read/write in multiple regions

**Features:**
- Geo-distributed databases with CRDT
- Bi-directional replication
- Local read/write in each region
- Automatic conflict resolution
- High availability across regions

---

### 3. Production (Recommended for Production)

**See:** [production/README.md](production/README.md)

Production-grade deployment with optimized resources and configurations.

**Use cases:**
- Production workloads
- High-performance requirements
- Large-scale deployments

**Features:**
- Optimized resource allocation
- Production-grade storage
- Enhanced monitoring
- Backup configurations

**Status:** 🚧 Coming soon

---

### 3. Active-Active (Multi-Region)

**See:** [active-active/README.md](active-active/README.md)

Geo-distributed Redis Enterprise deployment across multiple Kubernetes clusters.

**Use cases:**
- Multi-region deployments
- Global applications
- Disaster recovery
- Low-latency local reads/writes

**Features:**
- Conflict-free replication (CRDT)
- Local read/write in each region
- Automatic conflict resolution
- Business continuity

**Status:** 🚧 Coming soon

---

## Quick Start

### Prerequisites

1. **Kubernetes cluster** (EKS, GKE, AKS, OpenShift, or vanilla)
2. **Redis Enterprise Operator** installed ([operator/README.md](../operator/README.md))
3. **Storage** configured (see your platform's README in [platforms/](../platforms/))
4. **kubectl** configured and connected

### Basic Deployment (5 minutes)

```bash
# 1. Create namespace
kubectl apply -f single-region/00-namespace.yaml

# 2. Create secrets (admin: admin@redis.com / RedisAdmin123!, db: RedisAdmin123!)
kubectl apply -f single-region/01-rec-admin-secret.yaml
kubectl apply -f single-region/02-redb-secret.yaml

# 3. Apply RBAC
kubectl apply -f single-region/03-rbac-rack-awareness.yaml

# 4. Deploy cluster
kubectl apply -f single-region/04-rec.yaml

# 5. Wait for ready
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# 6. Create database (port 12000)
kubectl apply -f single-region/05-redb.yaml
```

**See:** [single-region/README.md](single-region/README.md) for detailed instructions.

---

## Architecture Decision

| Pattern | Complexity | HA | DR | Use Case |
|---------|-----------|----|----|----------|
| **Single-Region** | Low | ✅ | ❌ | Dev/Test, Single DC |
| **Production** | Medium | ✅ | ⚠️ | Production, High Performance |
| **Active-Active** | High | ✅ | ✅ | Multi-Region, Global Apps |

---

## Next Steps

After deploying Redis Enterprise:

1. **External Access:** Configure networking ([networking/](../networking/))
2. **Monitoring:** Set up observability ([monitoring/](../monitoring/))
3. **Security:** Implement security best practices ([security/](../security/))
4. **Backup:** Configure backup and restore ([backup-restore/](../backup-restore/))

---

## Platform-Specific Notes

### EKS
- Requires EBS CSI driver
- Use gp3 storage class
- See [platforms/eks/README.md](../platforms/eks/README.md)

### GKE
- Requires GCE PD CSI driver
- Use pd-ssd storage class
- See [platforms/gke/README.md](../platforms/gke/README.md)

### AKS
- Requires Azure Disk CSI driver
- Use managed-premium storage class
- See [platforms/aks/README.md](../platforms/aks/README.md)

### OpenShift
- Uses default storage class
- Requires SCC configuration
- See [platforms/openshift/README.md](../platforms/openshift/README.md)

### Vanilla Kubernetes
- Ensure storage class is available
- See [platforms/vanilla/README.md](../platforms/vanilla/README.md)

