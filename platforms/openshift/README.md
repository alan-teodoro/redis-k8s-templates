# Redis Enterprise on OpenShift - Deployment Templates

Professional deployment templates and guides for Redis Enterprise on OpenShift, designed for consultants and enterprise customers.

## 📋 Overview

This repository provides production-ready YAML configurations and step-by-step guides for deploying Redis Enterprise on OpenShift in two deployment patterns:

- **Single-Region**: Standard Redis Enterprise deployment in a single OpenShift cluster
- **Active-Active**: Geo-distributed Redis Enterprise deployment across multiple OpenShift clusters with conflict-free replication

## 🏗️ Architecture Patterns

### Single-Region Deployment
A Redis Enterprise Cluster (REC) deployed in a single OpenShift cluster with one or more Redis databases. Ideal for:
- Single data center deployments
- Development and testing environments
- Applications requiring high availability within a single region

### Active-Active Deployment
Redis Enterprise clusters deployed across multiple OpenShift clusters with Active-Active databases providing:
- Geo-distributed writes with conflict-free replication (CRDT)
- Local read/write latency in each region
- Automatic conflict resolution
- Disaster recovery and business continuity

## 📁 Repository Structure

```
.
├── README.md                          # This file
├── single-region/                     # Single cluster deployment
│   ├── README.md                      # Single-region guide
│   ├── 00-namespace.yaml              # Namespace creation
│   ├── 00-rec-admin-secret.yaml       # Admin credentials
│   ├── 01-rec.yaml                    # Redis Enterprise Cluster
│   ├── 02-redb-secret.yaml            # Database credentials
│   ├── 03-redb.yaml                   # Redis Database
│   ├── 04-route-ui.yaml               # UI access route
│   ├── 05-route-db.yaml               # Database access route
│   └── steps.txt                      # Deployment steps
├── active-active/                     # Multi-cluster deployment
│   ├── README.md                      # Active-Active guide
│   ├── clusterA/                      # Cluster A configurations
│   ├── clusterB/                      # Cluster B configurations
│   └── steps.txt                      # Deployment steps
├── monitoring/                        # Monitoring configuration
│   └── servicemonitor.yaml            # Prometheus ServiceMonitor
├── testing/                           # Load testing tools
│   └── memtier-benchmark.yaml         # Memtier benchmark pod
└── openshift/                         # OpenShift-specific configs
    └── scc.yaml                       # Security Context Constraints
```

## 🚀 Quick Start

### Prerequisites

1. **OpenShift Cluster(s)**
   - OpenShift 4.10+ (see [supported distributions](https://redis.io/docs/latest/operate/kubernetes/reference/supported_k8s_distributions/))
   - Cluster admin access
   - Sufficient resources (see [sizing guide](#resource-requirements))

2. **Redis Enterprise Operator**
   - Install from OperatorHub or manually
   - Version 7.4.2+ recommended

3. **Storage**
   - Persistent storage class available
   - Minimum 20Gi per Redis Enterprise node

4. **Network**
   - OpenShift Routes enabled (default)
   - External DNS configured (for production)

### Single-Region Deployment (5 minutes)

```bash
# 1. Create namespace
oc apply -f single-region/00-namespace.yaml

# 2. Install Redis Enterprise Operator (if not already installed)
# Via OperatorHub UI or:
oc apply -f openshift/operator-install.yaml

# 3. Apply configurations in order
oc apply -f single-region/00-rec-admin-secret.yaml
oc apply -f single-region/01-rec.yaml

# 4. Wait for cluster to be ready (3-5 minutes)
oc wait --for=condition=Ready rec/rec -n redis-ns-a --timeout=600s

# 5. Create database
oc apply -f single-region/02-redb-secret.yaml
oc apply -f single-region/03-redb.yaml

# 6. Create routes for access
oc apply -f single-region/04-route-ui.yaml
oc apply -f single-region/05-route-db.yaml

# 7. Get UI URL
oc get route route-ui -n redis-ns-a -o jsonpath='{.spec.host}'
```

**Default Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!` (⚠️ Change in production!)

### Active-Active Deployment

See [active-active/README.md](active-active/README.md) for detailed multi-cluster setup instructions.

## 📊 Resource Requirements

### Minimum Requirements (Development/Testing)
- **Nodes**: 3 Redis Enterprise nodes
- **CPU**: 2 cores per node (6 cores total)
- **Memory**: 4Gi per node (12Gi total)
- **Storage**: 20Gi per node (60Gi total)

### Production Recommendations
- **Nodes**: 3-9 nodes (odd number for quorum)
- **CPU**: 4-8 cores per node
- **Memory**: 16-32Gi per node
- **Storage**: 100Gi+ per node with high IOPS
- **Network**: Low latency between nodes (<1ms)

See [Redis Enterprise sizing guide](https://redis.io/docs/latest/operate/kubernetes/7.8.4/recommendations/sizing-on-kubernetes/) for detailed calculations.

## 🔐 Security Best Practices

1. **Change Default Passwords**: Update all secrets before production deployment
2. **Enable TLS**: Set `tlsMode: enabled` in database configurations
3. **Use RBAC**: Implement role-based access control
4. **Network Policies**: Restrict traffic between namespaces
5. **Secret Management**: Use OpenShift sealed secrets or external secret managers
6. **Regular Updates**: Keep operator and Redis Enterprise versions current

## 📈 Monitoring & Observability

Enable Prometheus monitoring:

```bash
# Enable user workload monitoring
oc apply -f monitoring/servicemonitor.yaml

# Access metrics in OpenShift Console
# Observe → Metrics → Custom Query
```

Common metrics to monitor:
- `redis_used_memory_bytes` - Memory usage
- `redis_connected_clients` - Active connections
- `redis_commands_processed_total` - Operations per second
- `redis_keyspace_hits_total` / `redis_keyspace_misses_total` - Cache hit ratio

## 🧪 Load Testing

Deploy memtier_benchmark for performance testing:

```bash
# Deploy memtier pod
oc apply -f testing/memtier-benchmark.yaml

# Run benchmark (TLS enabled)
oc exec -it memtier-shell -- memtier_benchmark \
  -s <db-service-dns> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <db-service-dns> \
  --ratio=1:4 --test-time=600 --pipeline=2 \
  --clients=2 --threads=2 --hide-histogram
```

See [testing/README.md](testing/README.md) for detailed benchmarking guide.

## 📚 Additional Resources

- [Redis Enterprise on Kubernetes Documentation](https://redis.io/docs/latest/operate/kubernetes/)
- [OpenShift Deployment Guide](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)
- [API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/api/)
- [Hardware Requirements](https://redis.io/docs/latest/operate/rs/installing-upgrading/install/plan-deployment/hardware-requirements/)
- [Persistent Volumes Best Practices](https://redis.io/docs/latest/operate/kubernetes/7.8.4/recommendations/persistent-volumes/)

## 🤝 Support

For issues and questions:
- Redis Enterprise Support Portal
- [Redis Community Forum](https://forum.redis.com/)
- OpenShift Support (for platform issues)

## 📝 License

This repository contains deployment templates and is provided as-is for Redis Enterprise customers and partners.

---

**Note**: This is a template repository. Always review and customize configurations for your specific environment before production deployment.

