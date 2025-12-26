# Active-Active Redis Enterprise Deployment

This directory contains YAML configurations for deploying Redis Enterprise Active-Active databases across two Kubernetes clusters.

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
│   Namespace: redis-enterprise   │      │   Namespace: redis-enterprise   │
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
│  │ Name: aadb               │◄──┼──────┼──►│ Name: aadb               │  │
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
├── cluster-a/                     # Cluster A configurations
│   ├── 00-namespace.yaml          # Namespace
│   ├── 01-rec-admin-secret.yaml   # Admin credentials
│   ├── 02-rbac-rack-awareness.yaml # RBAC for rack awareness
│   ├── 03-rec.yaml                # Redis Enterprise Cluster
│   ├── 04-rerc-secrets.yaml       # Remote cluster secrets
│   ├── 05-rerc.yaml               # Remote cluster definitions
│   ├── 06-reaadb-secret.yaml      # Database password
│   └── 07-reaadb.yaml             # Active-Active database
└── cluster-b/                     # Cluster B configurations
    ├── 00-namespace.yaml
    ├── 01-rec-admin-secret.yaml
    ├── 02-rbac-rack-awareness.yaml
    ├── 03-rec.yaml
    ├── 04-rerc-secrets.yaml
    ├── 05-rerc.yaml
    └── 06-reaadb-secret.yaml
```

**Note:** Database (REAADB) is created only on Cluster A and automatically replicates to Cluster B.

## 🚀 Deployment Steps

### Prerequisites

1. **Two Kubernetes clusters** with network connectivity between them
2. **Redis Enterprise Operator** installed in both clusters (see [operator/README.md](../operator/README.md))
3. **Network connectivity** between clusters (ports 8443, 9443, database ports)
4. **Admin access** to both clusters
5. **External access configured** (Ingress/LoadBalancer) for API and database endpoints

### Pre-Deployment Configuration

**⚠️ IMPORTANT: Update FQDNs for Your Environment**

Before deploying, you **must** update the FQDN (Fully Qualified Domain Name) values in the YAML files to match your environment.

**Files to update:**

1. **Cluster A** (`cluster-a/03-rec.yaml`):
   - Update `ingressOrRouteSpec.apiFqdnUrl` with your Cluster A API endpoint
   - Update `ingressOrRouteSpec.dbFqdnSuffix` with your Cluster A database suffix

2. **Cluster B** (`cluster-b/03-rec.yaml`):
   - Update `ingressOrRouteSpec.apiFqdnUrl` with your Cluster B API endpoint
   - Update `ingressOrRouteSpec.dbFqdnSuffix` with your Cluster B database suffix

3. **Remote cluster references** (`cluster-a/05-rerc.yaml` and `cluster-b/05-rerc.yaml`):
   - Update `apiFqdnUrl` and `dbFqdnSuffix` for both clusters

**Example:**
```yaml
# cluster-a/03-rec.yaml
ingressOrRouteSpec:
  apiFqdnUrl: api-rec-a.redis.example.com
  dbFqdnSuffix: .db-rec-a.redis.example.com
```

**See:** [../networking/README.md](../networking/README.md) for external access configuration options.

## 🔐 Default Credentials

**Pre-configured credentials for testing/demo purposes:**

| Component | Username | Password |
|-----------|----------|----------|
| **REC Admin** | `admin@redis.com` | `RedisAdmin123!` |
| **Database** | `default` | `RedisAdmin123!` |
| **Database Port** | - | `12000` |

**⚠️ SECURITY WARNING:** These are default credentials for testing/demo purposes only. **ALWAYS change passwords before production deployment!**

## 📝 Deployment Instructions

### Step 1: Deploy Redis Enterprise Clusters

**On Cluster A:**
```bash
# Set context to Cluster A
kubectl config use-context <cluster-a-context>

# Deploy REC
cd cluster-a/
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-rec-admin-secret.yaml
kubectl apply -f 02-rbac-rack-awareness.yaml
kubectl apply -f 03-rec.yaml

# Wait for cluster ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec-a -n redis-enterprise --timeout=600s
```

**On Cluster B:**
```bash
# Set context to Cluster B
kubectl config use-context <cluster-b-context>

# Deploy REC
cd cluster-b/
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-rec-admin-secret.yaml
kubectl apply -f 02-rbac-rack-awareness.yaml
kubectl apply -f 03-rec.yaml

# Wait for cluster ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec-b -n redis-enterprise --timeout=600s
```

### Step 2: Configure Remote Cluster Connections

**On Both Clusters:**
```bash
# Cluster A
kubectl config use-context <cluster-a-context>
kubectl apply -f cluster-a/04-rerc-secrets.yaml
kubectl apply -f cluster-a/05-rerc.yaml

# Cluster B
kubectl config use-context <cluster-b-context>
kubectl apply -f cluster-b/04-rerc-secrets.yaml
kubectl apply -f cluster-b/05-rerc.yaml

# Verify remote clusters
kubectl get rerc -n redis-enterprise  # Run on both clusters
```

### Step 3: Create Active-Active Database

**On Cluster A only:**
```bash
kubectl config use-context <cluster-a-context>
kubectl apply -f cluster-a/06-reaadb-secret.yaml
kubectl apply -f cluster-a/07-reaadb.yaml

# Wait for database creation
kubectl wait --for=condition=Active reaadb/aadb -n redis-enterprise --timeout=300s
```

**Note:** The database is created only on Cluster A. It will automatically replicate to Cluster B.

### Step 4: Verify Deployment

```bash
# Check REC status on both clusters
kubectl get rec -n redis-enterprise

# Check REAADB status
kubectl get reaadb -n redis-enterprise

# Check remote clusters
kubectl get rerc -n redis-enterprise
```

---

## 🔍 Verification

### Verify Active-Active Replication

**Test write replication:**
```bash
# Write to Cluster A
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  SET test-key "written-from-cluster-a"

# Read from Cluster B (should see the same value)
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  GET test-key
```

**Expected:** Value should replicate from Cluster A to Cluster B within seconds.

### Check Replication Status

In the Redis Enterprise UI:
1. Navigate to **Databases** → **aadb**
2. Check **Replication** tab
3. Verify both instances show "Synced" status

---

## 🔧 Configuration Details

### Redis Enterprise Cluster (REC)

- **Nodes:** 3 per cluster (for high availability)
- **CPU:** 2 cores per node
- **Memory:** 4Gi per node
- **Storage:** 10Gi per node
- **Rack Awareness:** Enabled (distributes across availability zones)

### Active-Active Database (REAADB)

- **Name:** aadb
- **Type:** Redis with CRDT
- **Memory:** 200MB (total across all instances)
- **Port:** 12000 (fixed for consistency)
- **Shards:** 1
- **Replication:** Enabled (master + replica per cluster)
- **TLS:** Enabled
- **Password:** From secret `reaadb-secret`

### Supported Modules

Not all Redis modules support Active-Active. Compatible modules include:
- **RedisJSON** (rejson)
- **RedisBloom** (bf)
- **RedisTimeSeries** (timeseries)

**Note:** Check [Redis Active-Active documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/develop/) for module compatibility.

---

## 🔍 Troubleshooting

### Remote Cluster Connection Issues

```bash
# Check RERC status
kubectl get rerc -n redis-enterprise
kubectl describe rerc rerc-b -n redis-enterprise

# Verify network connectivity from REC pod
kubectl exec -it rec-a-0 -n redis-enterprise -- \
  curl -k https://<cluster-b-api-fqdn>:9443
```

### Database Not Replicating

```bash
# Check database status
kubectl describe reaadb aadb -n redis-enterprise

# Check logs
kubectl logs -n redis-enterprise rec-a-0 | grep -i replication

# Verify participating clusters
kubectl get reaadb aadb -n redis-enterprise -o yaml | grep -A 5 participatingClusters
```

### TLS Certificate Issues

1. Access UI on both clusters
2. Navigate to **Cluster** → **Security** → **Certificates**
3. Download and compare certificates
4. Ensure certificates are valid and trusted

---

## 🧹 Cleanup

```bash
# Cluster A
kubectl config use-context <cluster-a-context>
kubectl delete -f cluster-a/07-reaadb.yaml
kubectl delete -f cluster-a/06-reaadb-secret.yaml
kubectl delete -f cluster-a/05-rerc.yaml
kubectl delete -f cluster-a/04-rerc-secrets.yaml
kubectl delete -f cluster-a/03-rec.yaml
kubectl delete -f cluster-a/02-rbac-rack-awareness.yaml
kubectl delete -f cluster-a/01-rec-admin-secret.yaml
kubectl delete -f cluster-a/00-namespace.yaml

# Cluster B
kubectl config use-context <cluster-b-context>
kubectl delete -f cluster-b/05-rerc.yaml
kubectl delete -f cluster-b/04-rerc-secrets.yaml
kubectl delete -f cluster-b/03-rec.yaml
kubectl delete -f cluster-b/02-rbac-rack-awareness.yaml
kubectl delete -f cluster-b/01-rec-admin-secret.yaml
kubectl delete -f cluster-b/00-namespace.yaml
```

---

## 📚 Additional Resources

- [Active-Active Geo-Distribution](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [CRDT Documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/develop/)
- [Network Requirements](https://redis.io/docs/latest/operate/rs/networking/port-configurations/)
- [Networking Configuration](../networking/README.md)


