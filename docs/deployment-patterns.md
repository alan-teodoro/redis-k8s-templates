# Redis Enterprise Deployment Patterns

Quick reference guide for choosing the right deployment pattern.

## Single-Cluster Deployment

**Use when:**
- Single region/datacenter deployment
- Standard HA requirements
- No geo-distribution needed
- Simplest operational model

**Architecture:**
- 3+ node Redis Enterprise Cluster (REC)
- Multiple databases (REDB) on the cluster
- Local HA via cluster replication

**Location:** `deployments/redis-enterprise/single-cluster/`

**Resources:**
- Minimum: 3 nodes, 4 CPU, 15GB RAM each
- Recommended: 3 nodes, 8 CPU, 30GB RAM each

---

## Active-Active Deployment

**Use when:**
- Multi-region deployment required
- Local read/write in each region
- Geo-distribution for low latency
- Conflict-free replication needed (CRDTs)

**Architecture:**
- Multiple REC clusters (one per region)
- Active-Active database (REAADB) replicated across clusters
- Bi-directional replication with conflict resolution

**Location:** `deployments/redis-enterprise/active-active/`

**Resources:**
- Per cluster: Same as single-cluster
- Minimum 2 clusters, can scale to 5+

**Network Requirements:**
- Cross-cluster connectivity (VPN, VPC peering, or public internet)
- Ports: 8443 (API), 9443 (sync)

---

## Active-Passive Deployment

**Use when:**
- Disaster recovery required
- Passive standby for failover
- One-way replication acceptable
- Cost optimization (passive can be smaller)

**Architecture:**
- Primary REC cluster (active)
- Secondary REC cluster (passive)
- One-way replication from primary to secondary
- Manual or automated failover

**Location:** `deployments/redis-enterprise/active-passive/`

**Resources:**
- Primary: Full production sizing
- Secondary: Can be smaller (2 nodes minimum)

---

## Deployment with Modules

**Use when:**
- RedisJSON, RediSearch, RedisGraph, RedisTimeSeries, or RedisBloom needed
- Advanced data structures required
- Specific module features needed

**Architecture:**
- Same as single-cluster or Active-Active
- Modules loaded at database creation
- Module-specific configuration

**Location:** `deployments/redis-enterprise/modules/`

**Supported Modules:**
- RedisJSON - JSON document storage
- RediSearch - Full-text search and indexing
- RedisGraph - Graph database
- RedisTimeSeries - Time-series data
- RedisBloom - Probabilistic data structures

---

## Platform-Specific Considerations

### OpenShift
- Use Routes for external access
- Security Context Constraints (SCC) required
- Operator installation via OperatorHub recommended

### EKS (AWS)
- Use NLB for LoadBalancer services
- EBS CSI driver for persistent storage
- IRSA for secrets access

### AKS (Azure)
- Use Azure Load Balancer
- Azure Disk CSI for storage
- Managed Identity for secrets

### GKE (Google Cloud)
- Use GCP Load Balancer
- Persistent Disk CSI for storage
- Workload Identity for secrets

---

## Decision Matrix

| Requirement | Pattern | Notes |
|-------------|---------|-------|
| Single region, HA | Single-Cluster | Simplest, most common |
| Multi-region, low latency | Active-Active | Best for geo-distribution |
| DR only | Active-Passive | Cost-effective DR |
| Advanced data types | With Modules | Any pattern + modules |
| Cost optimization | Single-Cluster | Minimal infrastructure |
| Maximum availability | Active-Active | Survives region failure |

---

## Next Steps

1. Choose your deployment pattern
2. Navigate to the pattern directory
3. Select your platform (EKS, AKS, GKE, OpenShift, vanilla)
4. Follow the step-by-step deployment guide

