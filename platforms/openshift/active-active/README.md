# Active-Active Redis Enterprise Deployment

This directory contains YAML configurations for deploying Redis Enterprise Active-Active databases across two OpenShift clusters.

## 📋 Overview

Active-Active deployment provides:
- **Geo-distributed databases** across multiple regions/clusters
- **Local read/write** in each region with low latency
- **Conflict-free replication** using CRDTs (Conflict-free Replicated Data Types)
- **Automatic conflict resolution** for concurrent writes
- **High availability** and disaster recovery

## 🏗️ Architecture

```
┌─────────────────────────────────┐      ┌─────────────────────────────────┐
│   Cluster A (Region 1)          │      │   Cluster B (Region 2)          │
│   Namespace: redis-ns-a         │      │   Namespace: redis-ns-b         │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Redis Enterprise Cluster │   │      │   │ Redis Enterprise Cluster │  │
│  │ Name: rec-a              │   │      │   │ Name: rec-b              │  │
│  │ Nodes: 3                 │   │      │   │ Nodes: 3                 │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Remote Cluster (rerc-a)  │◄──┼──────┼──►│ Remote Cluster (rerc-a)  │  │
│  │ Remote Cluster (rerc-b)  │◄──┼──────┼──►│ Remote Cluster (rerc-b)  │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Active-Active Database   │   │      │   │ Active-Active Database   │  │
│  │ Name: reaadb-aadb        │◄──┼──────┼──►│ Name: reaadb-aadb        │  │
│  │ Port: 12000              │   │      │   │ Port: 12000              │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  Application writes locally ────┼──────┼──── Application writes locally  │
│  Reads from local instance      │      │     Reads from local instance   │
└─────────────────────────────────┘      └─────────────────────────────────┘
           │                                            │
           └────────────── Bi-directional ─────────────┘
                        Replication (CRDT)
```

## 📁 Directory Structure

```
active-active/
├── README.md                      # This file
├── steps.txt                      # Detailed deployment steps
├── clusterA/                      # Cluster A configurations
│   ├── 00-rec-admin-secret.yaml   # Admin credentials
│   ├── 00-rec.yaml                # Redis Enterprise Cluster
│   ├── 01-rerc-secrets.yaml       # Remote cluster secrets
│   ├── 01-rerc.yaml               # Remote cluster definitions
│   ├── 02-reaadb-secret.yaml      # Database password
│   ├── 02-reaadb.yaml             # Active-Active database
│   └── 03-route-ui.yaml           # UI route
└── clusterB/                      # Cluster B configurations
    ├── 00-rec-admin-secret.yaml
    ├── 00-rec.yaml
    ├── 01-rerc-secrets.yaml
    ├── 01-rerc.yaml
    ├── 02-reaadb-secret.yaml
    ├── 02-reaadb.yaml
    └── 03-route-ui.yaml
```

## 🚀 Deployment Steps

### Prerequisites

1. **Two OpenShift clusters** with network connectivity between them
2. **Redis Enterprise Operator** installed in both clusters
3. **Cluster domains** configured and accessible
4. **Admin access** to both clusters
5. **Network connectivity** between clusters (ports 8443, 9443, database ports)

### Pre-Deployment Configuration

**⚠️ IMPORTANT: Update FQDN Suffixes for Your Environment**

Before deploying, you **must** replace all FQDN (Fully Qualified Domain Name) suffixes in the YAML files to match your OpenShift cluster domains. The example files use demo cluster domains that will not work in your environment.

**How to find your cluster domain:**
```bash
# Get your cluster's default route domain
oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'
```

**Files to update:**

1. **Cluster A files** (`clusterA/00-rec.yaml`):
   - Replace `apps.cluster-lwrtg.dynamic.redhatworkshops.io` with your Cluster A domain
   - Update both `apiFqdnUrl` and `dbFqdnSuffix` fields

2. **Cluster B files** (`clusterB/00-rec.yaml`):
   - Replace `apps.cluster-2mp82.dynamic.redhatworkshops.io` with your Cluster B domain
   - Update both `apiFqdnUrl` and `dbFqdnSuffix` fields

3. **Remote cluster references** in `clusterA/01-rerc.yaml`:
   - Update `apiFqdnUrl` and `dbFqdnSuffix` for both `rerc-a` and `rerc-b` resources
   - Use Cluster A domain for `rerc-a` and Cluster B domain for `rerc-b`

4. **Remote cluster references** in `clusterB/01-recr.yaml`:
   - Update `apiFqdnUrl` and `dbFqdnSuffix` for both `rerc-a` and `rerc-b` resources
   - Use Cluster A domain for `rerc-a` and Cluster B domain for `rerc-b`

**Example replacement:**

If your Cluster A domain is `apps.prod-cluster-1.example.com`, change:
```yaml
# Before (example domain)
apiFqdnUrl: api-rec-a-redis-ns-a.apps.cluster-lwrtg.dynamic.redhatworkshops.io
dbFqdnSuffix: -db-rec-a-redis-ns-a.apps.cluster-lwrtg.dynamic.redhatworkshops.io

# After (your domain)
apiFqdnUrl: api-rec-a-redis-ns-a.apps.prod-cluster-1.example.com
dbFqdnSuffix: -db-rec-a-redis-ns-a.apps.prod-cluster-1.example.com
```

**Quick find and replace:**
```bash
# For Cluster A files
find clusterA/ -name "*.yaml" -exec sed -i '' \
  's/apps.cluster-lwrtg.dynamic.redhatworkshops.io/apps.YOUR-CLUSTER-A-DOMAIN/g' {} +

# For Cluster B files
find clusterB/ -name "*.yaml" -exec sed -i '' \
  's/apps.cluster-2mp82.dynamic.redhatworkshops.io/apps.YOUR-CLUSTER-B-DOMAIN/g' {} +
```

### Step 1: Deploy Redis Enterprise Clusters

**On Cluster A:**
```bash
# Set context to Cluster A
oc login <cluster-a-api-url>

# Create namespace
oc create namespace redis-ns-a

# Deploy REC
oc apply -f clusterA/00-rec-admin-secret.yaml
oc apply -f clusterA/00-rec.yaml

# Wait for cluster ready
oc wait --for=condition=Ready rec/rec-a -n redis-ns-a --timeout=600s
```

**On Cluster B:**
```bash
# Set context to Cluster B
oc login <cluster-b-api-url>

# Create namespace
oc create namespace redis-ns-b

# Deploy REC
oc apply -f clusterB/00-rec-admin-secret.yaml
oc apply -f clusterB/00-rec.yaml

# Wait for cluster ready
oc wait --for=condition=Ready rec/rec-b -n redis-ns-b --timeout=600s
```

### Step 2: Configure Remote Cluster Connections

**On Both Clusters:**
```bash
# Cluster A
oc apply -f clusterA/01-rerc-secrets.yaml
oc apply -f clusterA/01-rerc.yaml

# Cluster B
oc apply -f clusterB/01-rerc-secrets.yaml
oc apply -f clusterB/01-rerc.yaml

# Verify remote clusters
oc get rerc -n redis-ns-a  # On Cluster A
oc get rerc -n redis-ns-b  # On Cluster B
```

### Step 3: Create Active-Active Database

**On Cluster A:**
```bash
oc apply -f clusterA/02-reaadb-secret.yaml
oc apply -f clusterA/02-reaadb.yaml

# Wait for database creation
oc wait --for=condition=Ready reaadb/reaadb-aadb -n redis-ns-a --timeout=300s
```

**Note:** The database is created only on Cluster A. It will automatically replicate to Cluster B.

### Step 4: Create UI Routes

```bash
# Cluster A
oc apply -f clusterA/03-route-ui.yaml

# Cluster B
oc apply -f clusterB/03-route-ui.yaml

# Get UI URLs
oc get route route-ui -n redis-ns-a  # Cluster A
oc get route route-ui -n redis-ns-b  # Cluster B
```

## 🔐 Access Information

### UI Access

**Cluster A:**
```bash
echo "https://$(oc get route route-ui -n redis-ns-a -o jsonpath='{.spec.host}')"
```

**Cluster B:**
```bash
echo "https://$(oc get route route-ui -n redis-ns-b -o jsonpath='{.spec.host}')"
```

**Credentials:**
- Username: `admin@redis.com`
- Password: `RedisAdmin123!`

### Database Access

**Connection Details:**
- Port: `443` (via route) or `12000` (internal)
- Username: `default`
- Password: `RedisAdmin123!`
- TLS: Enabled
- SNI: Required

**Example connection string:**
```bash
redis-cli -h reaadb-aadb-db-rec-a-redis-ns-a.apps.<cluster-domain> \
  -p 443 \
  --tls \
  --sni reaadb-aadb-db-rec-a-redis-ns-a.apps.<cluster-domain> \
  -a RedisAdmin123!
```

## 🔧 Configuration Options

### Database Configuration

Edit `02-reaadb.yaml` to customize:

```yaml
spec:
  globalConfigurations:
    memorySize: 200MB              # Total memory across all instances
    shardCount: 1                  # Number of shards
    replication: true              # Enable replica for HA
    modulesList:                   # Redis modules (must support CRDT)
      - name: rejson
        version: 2.8.10
```

**Important:** Not all Redis modules support Active-Active. Check compatibility before enabling.

## 🔍 Verification

### Verify Active-Active Replication

**Test write replication:**
```bash
# Write to Cluster A
redis-cli -h <cluster-a-db-host> -p 443 --tls --sni <cluster-a-db-host> -a RedisAdmin123! \
  SET test-key "written-from-cluster-a"

# Read from Cluster B (should see the same value)
redis-cli -h <cluster-b-db-host> -p 443 --tls --sni <cluster-b-db-host> -a RedisAdmin123! \
  GET test-key
```

### Check Replication Status

In the Redis Enterprise UI:
1. Navigate to **Databases** → **reaadb-aadb**
2. Check **Replication** tab
3. Verify both instances show "Synced" status

## 📊 Monitoring

Deploy ServiceMonitor on both clusters:

```bash
# Update namespace in monitoring/servicemonitor.yaml
# Then apply on both clusters
oc apply -f ../monitoring/servicemonitor.yaml
```

## 🔍 Troubleshooting

### Remote Cluster Connection Issues

```bash
# Check RERC status
oc get rerc -n redis-ns-a
oc describe rerc rerc-b -n redis-ns-a

# Verify network connectivity
oc exec -it rec-a-0 -n redis-ns-a -- curl -k https://api-rec-b-redis-ns-b.apps.<cluster-b-domain>:9443
```

### Database Not Replicating

```bash
# Check database status
oc describe reaadb reaadb-aadb -n redis-ns-a

# Check logs
oc logs -n redis-ns-a rec-a-0 | grep -i replication

# Verify participating clusters
oc get reaadb reaadb-aadb -n redis-ns-a -o yaml | grep -A 5 participatingClusters
```

### TLS Certificate Issues

1. Access UI on both clusters
2. Navigate to **Cluster** → **Security** → **Certificates**
3. Download and compare certificates
4. Ensure certificates are valid and trusted

## 🧹 Cleanup

```bash
# Cluster A
oc delete -f clusterA/03-route-ui.yaml
oc delete -f clusterA/02-reaadb.yaml
oc delete -f clusterA/02-reaadb-secret.yaml
oc delete -f clusterA/01-rerc.yaml
oc delete -f clusterA/01-rerc-secrets.yaml
oc delete -f clusterA/00-rec.yaml
oc delete -f clusterA/00-rec-admin-secret.yaml
oc delete namespace redis-ns-a

# Cluster B
oc delete -f clusterB/03-route-ui.yaml
oc delete -f clusterB/01-rerc.yaml
oc delete -f clusterB/01-rerc-secrets.yaml
oc delete -f clusterB/00-rec.yaml
oc delete -f clusterB/00-rec-admin-secret.yaml
oc delete namespace redis-ns-b
```

## 📚 Additional Resources

- [Active-Active Geo-Distribution](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [CRDT Documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/develop/)
- [Network Requirements](https://redis.io/docs/latest/operate/rs/networking/port-configurations/)

