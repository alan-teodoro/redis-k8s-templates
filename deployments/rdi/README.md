# RDI (Redis Data Integration) on Kubernetes

**RDI** is Redis Enterprise's data integration solution that enables real-time replication of data from relational databases (Oracle, PostgreSQL, MySQL, SQL Server, etc.) to Redis using **Change Data Capture (CDC)**.

---

## 📋 Overview

### What is RDI?

RDI captures changes from relational databases in real-time and replicates them to Redis Enterprise, enabling:

- **Application modernization**: Cache relational data in Redis
- **Event-driven architectures**: Stream database change events
- **Real-time analytics**: Analyze data in real-time
- **Microservices data**: Synchronize data between microservices

### Architecture

```
Source Database (Oracle/PostgreSQL/MySQL/SQL Server)
         ↓ (CDC)
    RDI Collector (Debezium)
         ↓
    RDI Stream Processor
         ↓
Redis Enterprise Cluster (Target)
```

### Kubernetes Components

Helm Chart installation creates:

- **RDI Operator**: Manages RDI lifecycle
- **RDI API Server**: REST API for configuration and management
- **Metrics Exporter**: Exports Prometheus metrics
- **CDC Collector**: Captures changes from source database
- **Stream Processor**: Processes and transforms data before writing to Redis
- **ConfigMap**: RDI database connection details
- **Secrets**: Credentials and TLS certificates

---

## 🎯 Prerequisites

### 1. Redis Enterprise Cluster

- **Version**: Redis Enterprise 6.4 or higher
- **REC already installed**: This guide assumes you already have a REC running

### 2. RDI Database

RDI requires a Redis Enterprise database to store its state. **Critical requirements**:

| Requirement | Value | Reason |
|-----------|-------|--------|
| **RAM** | 250MB (prod) / 125MB (dev) | State storage |
| **Replication** | 1 primary + 1 replica (prod) | High availability |
| **Eviction Policy** | `noeviction` | **CRITICAL** - Never evict state data |
| **Persistence** | AOF - fsync every 1 sec | State durability |
| **Clustering** | **DISABLED** | **CRITICAL** - RDI does not work with clustered databases |
| **TLS** | Recommended (prod) | Security |
| **Password** | Recommended (prod) | Security |

⚠️ **WARNING**: If the RDI database is clustered, RDI **WILL NOT WORK**. You must create a new database with clustering disabled.

### 3. Source Database

Relational database prepared for CDC:
- Oracle
- PostgreSQL
- MySQL
- SQL Server
- MariaDB
- Google Cloud Spanner

### 4. Kubernetes

- **Supported versions**: Only non-EOL (End of Life) versions
- **OpenShift**: Supported (requires additional configuration)
- **Cloud providers**: EKS, AKS, GKE supported

### 5. Helm Chart

Download Redis Helm Chart:

```bash
export RDI_VERSION=1.15.1
wget https://redis-enterprise-software-downloads.s3.amazonaws.com/redis-di/rdi-$RDI_VERSION.tgz
```

---

## 📁 Files in this Directory

| File | Description |
|---------|-----------|
| `01-rdi-database.yaml` | REDB for RDI state storage (noeviction, AOF, non-clustered) |
| `02-rdi-values-basic.yaml` | Basic Helm values (dev/test) |
| `03-rdi-values-production.yaml` | Production Helm values (TLS, HA, monitoring) |
| `04-rdi-values-openshift.yaml` | Helm values for OpenShift (SCCs) |
| `05-rdi-values-private-registry.yaml` | Helm values for private image registry |
| `06-ingress-nginx.yaml` | NGINX Ingress for RDI API |
| `07-ingress-gateway-api.yaml` | Gateway API for RDI API |
| `08-source-database-prep.md` | Source database preparation for CDC |
| `09-pipeline-examples.md` | RDI pipeline examples |
| `10-troubleshooting.md` | Troubleshooting and logs |

---

## 🚀 Quick Installation

### Step 1: Create RDI Database

```bash
# Apply REDB for RDI
kubectl apply -f 01-rdi-database.yaml -n redis-enterprise

# Verify creation
kubectl get redb rdi-database -n redis-enterprise

# Get database password
kubectl get secret redb-rdi-database -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

⚠️ **IMPORTANT**: Verify that the database is **NOT clustered**:

```bash
# Via Redis Enterprise UI: Configuration → Database clustering = None
# Or via REST API:
curl -k -u admin@redis.com:RedisAdmin123! \
  https://rec-redis-enterprise.redis-enterprise.svc.cluster.local:9443/v1/bdbs | \
  jq '.[] | select(.name=="rdi-database") | .sharding'
# Should return: false
```

### Step 2: Generate JWT Key

```bash
# Generate 256-bit (32 bytes) JWT key
JWT_KEY=$(head -c 32 /dev/urandom | base64)
echo "JWT Key: $JWT_KEY"
# Save this key - you will need it in values.yaml
```

### Step 3: Prepare values.yaml

```bash
# Scaffold default values.yaml
helm show values rdi-$RDI_VERSION.tgz > rdi-values.yaml

# Edit minimum required values:
# - connection.host
# - connection.port
# - connection.password
# - api.jwtKey
```

### Step 4: Install RDI via Helm

```bash
# Install RDI in 'rdi' namespace
helm upgrade --install rdi rdi-$RDI_VERSION.tgz \
  -f rdi-values.yaml \
  -n rdi \
  --create-namespace

# Verify installation
helm list -n rdi
kubectl get pods -n rdi
```

### Step 5: Verify Pods

```bash
kubectl get pods -n rdi

# Should show:
# NAME                      READY  STATUS   RESTARTS  AGE
# collector-api-xxx         1/1    Running  0         2m
# rdi-api-xxx               1/1    Running  0         2m
# rdi-metric-exporter-xxx   1/1    Running  0         2m
# rdi-operator-xxx          1/1    Running  0         2m
# rdi-reloader-xxx          1/1    Running  0         2m
```

---

## 📊 Next Steps

1. **Prepare Source Database**: See `08-source-database-prep.md`
2. **Configure Pipeline**: Use Redis Insight or RDI CLI
3. **Configure Observability**: See `observability/rdi/`
4. **Troubleshooting**: See `10-troubleshooting.md`

---

## 🔗 Useful Links

- [RDI Documentation](https://redis.io/docs/latest/integrate/redis-data-integration/)
- [RDI in Redis Insight](https://redis.io/docs/latest/operate/redisinsight/rdi/)
- [Prepare Source Databases](https://redis.io/docs/latest/integrate/redis-data-integration/data-pipelines/prepare-dbs/)

---

## ⚠️ Important Warnings

1. **RDI Database must NEVER be clustered** - RDI will not work
2. **Eviction Policy MUST be noeviction** - State loss will cause failures
3. **Persistence MUST be AOF** - Ensures state durability
4. **JWT Key must be 256 bits** - API security
5. **OpenShift requires custom SCCs** - See `04-rdi-values-openshift.yaml`

---

**Status**: ✅ Production Ready
**RDI Version**: 1.15.1
**Redis Enterprise**: 6.4+

