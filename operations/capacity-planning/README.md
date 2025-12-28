# Capacity Planning for Redis Enterprise on Kubernetes

Complete guide for capacity planning and resource sizing for Redis Enterprise deployments.

## 📋 Table of Contents

- [Overview](#overview)
- [Resource Requirements](#resource-requirements)
- [Sizing Guidelines](#sizing-guidelines)
- [Calculation Examples](#calculation-examples)
- [Monitoring and Scaling](#monitoring-and-scaling)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Proper capacity planning ensures:
- ✅ Optimal performance
- ✅ Cost efficiency
- ✅ Room for growth
- ✅ High availability

**Key Factors:**
- Data size
- Operations per second (OPS)
- Replication requirements
- Persistence settings
- High availability needs

---

## 📊 Resource Requirements

### Minimum Requirements (Development/Testing)

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| **REC Node** | 2 cores | 4 GB | 20 GB |
| **Database** | 0.5 cores | 1 GB | 5 GB |

### Production Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| **REC Node** | 4-8 cores | 16-32 GB | 100-500 GB |
| **Database** | 2-4 cores | 4-16 GB | 50-200 GB |

---

## 📐 Sizing Guidelines

### Memory Sizing

**Formula:**
```
Total Memory = (Dataset Size × Replication Factor × Overhead Factor) + Buffer
```

**Factors:**
- **Dataset Size**: Actual data size
- **Replication Factor**: 2 for HA (1 master + 1 replica)
- **Overhead Factor**: 1.2-1.5 (20-50% overhead for Redis internals)
- **Buffer**: 20% for growth

**Example:**
```
Dataset: 10 GB
Replication: 2x (master + replica)
Overhead: 1.3x
Buffer: 20%

Total = (10 GB × 2 × 1.3) + 20%
      = 26 GB + 5.2 GB
      = 31.2 GB ≈ 32 GB
```

### CPU Sizing

**Guidelines:**
- **Light workload** (< 10K OPS): 2 cores
- **Medium workload** (10K-50K OPS): 4 cores
- **Heavy workload** (50K-100K OPS): 8 cores
- **Very heavy** (> 100K OPS): 16+ cores or sharding

**Formula:**
```
CPU Cores = (Target OPS / 25000) × Replication Factor
```

**Example:**
```
Target OPS: 50,000
Replication: 2x

CPU = (50,000 / 25,000) × 2
    = 2 × 2
    = 4 cores
```

### Storage Sizing

**Formula:**
```
Storage = (Dataset Size × Replication Factor × Persistence Factor) + Snapshots + Buffer
```

**Persistence Factors:**
- **No persistence**: 1.0x
- **AOF**: 1.5x
- **Snapshot**: 2.0x
- **AOF + Snapshot**: 2.5x

**Example:**
```
Dataset: 10 GB
Replication: 2x
Persistence: AOF (1.5x)
Snapshots: 2 × 10 GB = 20 GB
Buffer: 20%

Storage = (10 GB × 2 × 1.5) + 20 GB + 20%
        = 30 GB + 20 GB + 10 GB
        = 60 GB
```

---

## 🧮 Calculation Examples

### Example 1: Small Production Database

**Requirements:**
- Dataset: 5 GB
- OPS: 10,000
- HA: Yes (replication)
- Persistence: AOF

**Calculations:**

**Memory:**
```
Total = (5 GB × 2 × 1.3) + 20%
      = 13 GB + 2.6 GB
      = 15.6 GB ≈ 16 GB
```

**CPU:**
```
CPU = (10,000 / 25,000) × 2
    = 0.4 × 2
    = 0.8 cores ≈ 2 cores (minimum)
```

**Storage:**
```
Storage = (5 GB × 2 × 1.5) + 10 GB + 20%
        = 15 GB + 10 GB + 5 GB
        = 30 GB
```

**Recommendation:**
```yaml
spec:
  memorySize: 16GB
  redisEnterpriseNodeResources:
    requests:
      cpu: "2"
      memory: 16Gi
  persistentSpec:
    volumeSize: 50Gi  # 30 GB + growth
```

---

### Example 2: Large Production Database

**Requirements:**
- Dataset: 100 GB
- OPS: 100,000
- HA: Yes (replication)
- Persistence: AOF + Snapshots
- Sharding: 4 shards

**Calculations:**

**Memory (per shard):**
```
Per Shard = 100 GB / 4 = 25 GB
Total = (25 GB × 2 × 1.3) + 20%
      = 65 GB + 13 GB
      = 78 GB ≈ 80 GB per shard
```

**CPU (per shard):**
```
OPS per shard = 100,000 / 4 = 25,000
CPU = (25,000 / 25,000) × 2
    = 1 × 2
    = 2 cores per shard
```

**Storage (per shard):**
```
Storage = (25 GB × 2 × 2.5) + 50 GB + 20%
        = 125 GB + 50 GB + 35 GB
        = 210 GB per shard
```

**Recommendation:**
```yaml
spec:
  memorySize: 100GB
  shardCount: 4
  replicasPerShard: 1
  redisEnterpriseNodeResources:
    requests:
      cpu: "8"  # 2 cores × 4 shards
      memory: 80Gi
  persistentSpec:
    volumeSize: 250Gi  # 210 GB + growth
```

---

## 📈 Monitoring and Scaling

### Key Metrics to Monitor

```bash
# Memory usage
kubectl top pods -n redis-enterprise

# Database metrics
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status databases

# CPU usage
kubectl top nodes
```

### Scaling Triggers

**Scale Up (Vertical):**
- Memory usage > 80%
- CPU usage > 70%
- Latency increasing

**Scale Out (Horizontal):**
- OPS approaching limits
- Need for geographic distribution
- Sharding required

### Scaling Commands

```bash
# Scale cluster nodes
kubectl patch rec rec -n redis-enterprise --type='json' \
  -p='[{"op": "replace", "path": "/spec/nodes", "value": 5}]'

# Increase database memory
kubectl patch redb redis-db -n redis-enterprise --type='json' \
  -p='[{"op": "replace", "path": "/spec/memorySize", "value": "8GB"}]'

# Add shards
kubectl patch redb redis-db -n redis-enterprise --type='json' \
  -p='[{"op": "replace", "path": "/spec/shardCount", "value": 4}]'
```

---

## ✅ Best Practices

### 1. **Plan for Growth**
- ✅ Add 20-30% buffer for growth
- ✅ Monitor trends over time
- ✅ Review capacity quarterly

### 2. **Use Appropriate Persistence**
- ✅ AOF for minimal data loss
- ✅ Snapshots for less critical data
- ✅ No persistence for cache-only

### 3. **Enable Replication**
- ✅ Always use replication in production
- ✅ Factor 2x memory for HA
- ✅ Consider Active-Active for DR

### 4. **Monitor Continuously**
- ✅ Set up alerts for high usage
- ✅ Track growth trends
- ✅ Plan scaling in advance

### 5. **Test at Scale**
- ✅ Load test before production
- ✅ Verify performance targets
- ✅ Validate failover scenarios

---

## 📚 Related Documentation

- [HA & Disaster Recovery](../ha-disaster-recovery/README.md)
- [Monitoring](../../observability/monitoring/README.md)
- [Performance Testing](../performance-testing/README.md)

---

## 🔗 References

- Redis Enterprise Sizing: https://redis.io/docs/latest/operate/rs/installing-upgrading/install/plan-deployment/
- Kubernetes Resource Management: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

