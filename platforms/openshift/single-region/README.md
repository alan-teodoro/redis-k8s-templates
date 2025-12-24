# Single-Region Redis Enterprise Deployment

This directory contains YAML configurations for deploying Redis Enterprise in a single OpenShift cluster.

## 📋 Overview

A single-region deployment creates:
- **Redis Enterprise Cluster (REC)**: 3-node cluster for high availability
- **Redis Database (REDB)**: One or more databases running on the cluster
- **OpenShift Routes**: External access to UI and database
- **Monitoring**: Prometheus metrics integration (optional)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│           OpenShift Cluster (redis-ns-a)            │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │   Redis Enterprise Cluster (rec)              │ │
│  │                                               │ │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐     │ │
│  │   │ Node 1  │  │ Node 2  │  │ Node 3  │     │ │
│  │   │ 2CPU/4Gi│  │ 2CPU/4Gi│  │ 2CPU/4Gi│     │ │
│  │   └─────────┘  └─────────┘  └─────────┘     │ │
│  │                                               │ │
│  │   ┌─────────────────────────────────────┐    │ │
│  │   │  Redis Database (redb)              │    │ │
│  │   │  - 200MB memory                     │    │ │
│  │   │  - 1 shard                          │    │ │
│  │   │  - Port 12000                       │    │ │
│  │   │  - TLS enabled                      │    │ │
│  │   └─────────────────────────────────────┘    │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  Routes:                                            │
│  - route-ui  → Redis Enterprise UI                 │
│  - route-db  → Database external access            │
└─────────────────────────────────────────────────────┘
```

## 📁 Files

| File | Description | Required |
|------|-------------|----------|
| `00-namespace.yaml` | Creates redis-ns-a namespace | Yes |
| `00-rec-admin-secret.yaml` | Admin credentials for REC | Yes |
| `01-rec.yaml` | Redis Enterprise Cluster definition | Yes |
| `02-redb-secret.yaml` | Database password | Yes |
| `03-redb.yaml` | Redis Database definition | Yes |
| `04-route-ui.yaml` | Route for UI access | Recommended |
| `05-route-db.yaml` | Route for database access | Optional |
| `steps.txt` | Detailed deployment steps | Reference |

## 🚀 Quick Deployment

### Prerequisites

1. OpenShift cluster with admin access
2. Redis Enterprise Operator installed
3. Default storage class configured
4. At least 6 CPU cores and 12Gi memory available

### Step-by-Step Deployment

```bash
# 1. Create namespace
oc apply -f 00-namespace.yaml

# 2. Create admin secret
oc apply -f 00-rec-admin-secret.yaml

# 3. Deploy Redis Enterprise Cluster
oc apply -f 01-rec.yaml

# 4. Wait for cluster to be ready (3-5 minutes)
oc wait --for=condition=Ready rec/rec -n redis-ns-a --timeout=600s

# 5. Verify cluster status
oc get rec -n redis-ns-a
oc get pods -n redis-ns-a

# 6. Create database secret
oc apply -f 02-redb-secret.yaml

# 7. Create database
oc apply -f 03-redb.yaml

# 8. Wait for database to be ready
oc wait --for=condition=Ready redb/redb -n redis-ns-a --timeout=300s

# 9. Create routes for access
oc apply -f 04-route-ui.yaml
oc apply -f 05-route-db.yaml

# 10. Get access URLs
echo "UI URL: https://$(oc get route route-ui -n redis-ns-a -o jsonpath='{.spec.host}')"
echo "DB URL: $(oc get route route-db -n redis-ns-a -o jsonpath='{.spec.host}')"
```

## 🔐 Access Credentials

### Default Credentials (⚠️ Change for Production!)

**Redis Enterprise UI:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

**Database:**
- Username: `default`
- Password: `RedisAdmin123!`

### Changing Credentials

To generate new base64-encoded credentials:

```bash
# Encode new credentials
echo -n 'your-username@example.com' | base64
echo -n 'YourSecurePassword123!' | base64

# Update the secrets YAML files with the base64 output
# Then apply: oc apply -f 00-rec-admin-secret.yaml
```

## 🔧 Customization

### Before Deployment

**Update `01-rec.yaml`:**
1. Replace `<your-cluster-domain>` with your actual OpenShift cluster domain
2. Adjust resource requests/limits based on your requirements
3. Configure storage class if needed

**Example:**
```yaml
ingressOrRouteSpec:
  apiFqdnUrl: api-rec-redis-ns-a.apps.mycluster.example.com
  dbFqdnSuffix: -db-rec-redis-ns-a.apps.mycluster.example.com
```

### Database Configuration Options

Edit `03-redb.yaml` to customize:

```yaml
spec:
  memorySize: 200MB              # Adjust based on needs
  shardCount: 1                  # Increase for larger datasets
  replication: true              # Enable for HA (requires 2x memory)
  rackAware: true                # Distribute across availability zones
  tlsMode: enabled               # TLS encryption
  modulesList:                   # Enable Redis modules
    - name: search
      version: 2.10.10
    - name: rejson
      version: 2.8.10
```

## 📊 Monitoring

### Enable Prometheus Monitoring

```bash
# Apply ServiceMonitor
oc apply -f ../monitoring/servicemonitor.yaml

# View metrics in OpenShift Console
# Navigate to: Observe → Metrics
```

### Key Metrics to Monitor

- `redis_used_memory_bytes` - Memory usage
- `redis_connected_clients` - Active connections
- `redis_commands_processed_total` - Operations/sec
- `redis_keyspace_hits_total` - Cache hits
- `redis_keyspace_misses_total` - Cache misses

## 🧪 Testing

### Deploy Load Testing Tool

```bash
oc apply -f ../testing/memtier-benchmark.yaml
```

### Run Performance Test

```bash
# Get database details
DB_HOST=$(oc get route route-db -n redis-ns-a -o jsonpath='{.spec.host}')
DB_PASSWORD="RedisAdmin123!"

# Run benchmark
oc exec -it memtier-shell -n redis-ns-a -- memtier_benchmark \
  -s redb.redis-ns-a.svc.cluster.local \
  -p 12000 \
  -a $DB_PASSWORD \
  --tls --tls-skip-verify \
  --sni redb.redis-ns-a.svc.cluster.local \
  --ratio=1:4 --test-time=300 \
  --clients=5 --threads=2
```

## 🔍 Troubleshooting

### Cluster Not Ready

```bash
# Check operator logs
oc logs -n redis-ns-a -l name=redis-enterprise-operator

# Check cluster events
oc describe rec rec -n redis-ns-a

# Check pod status
oc get pods -n redis-ns-a
oc describe pod <pod-name> -n redis-ns-a
```

### Database Not Creating

```bash
# Check database status
oc describe redb redb -n redis-ns-a

# Check if cluster is ready
oc get rec rec -n redis-ns-a

# Verify secret exists
oc get secret redb-secret -n redis-ns-a
```

### Cannot Access UI

```bash
# Check route
oc get route route-ui -n redis-ns-a

# Check service
oc get svc rec-ui -n redis-ns-a

# Test connectivity
curl -k https://$(oc get route route-ui -n redis-ns-a -o jsonpath='{.spec.host}')
```

## 🧹 Cleanup

```bash
# Delete in reverse order
oc delete -f 05-route-db.yaml
oc delete -f 04-route-ui.yaml
oc delete -f 03-redb.yaml
oc delete -f 02-redb-secret.yaml
oc delete -f 01-rec.yaml
oc delete -f 00-rec-admin-secret.yaml
oc delete -f 00-namespace.yaml
```

## 📚 Additional Resources

- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)
- [Database Configuration Reference](https://redis.io/docs/latest/operate/kubernetes/reference/api/)
- [OpenShift Routes](https://redis.io/docs/latest/operate/kubernetes/networking/routes/)
- [Sizing Guide](https://redis.io/docs/latest/operate/kubernetes/7.8.4/recommendations/sizing-on-kubernetes/)

