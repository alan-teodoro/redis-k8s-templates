# Multi-Namespace REDB Deployment

✅ **FULLY SUPPORTED** - Redis Enterprise Operator 6.4.2-4+

This deployment pattern allows a **single Redis Enterprise Operator and REC** to manage databases (REDB/REAADB) across **multiple Kubernetes namespaces**.

---

## ⚠️ Important Notes

**Supported Patterns** (same Kubernetes cluster):
- ✅ Single REC, single namespace (simplest)
- ✅ **Single REC, multiple namespaces** (this guide)
- ✅ Multiple RECs, multiple namespaces (one REC per namespace)

**NOT Supported**:
- ❌ Multiple RECs in one namespace
- ❌ Cross-Kubernetes-cluster operations (use Active-Active instead)

**Prerequisites**:
- Redis Enterprise Operator 6.4.2-4 or later (for label-based method)
- One REC already deployed in a namespace (e.g., `redis-enterprise`)
- Each consumer namespace must have proper RBAC configured **before** operator watches it

⚠️ **CRITICAL**: Only configure the operator to watch a namespace **after** the namespace exists and RBAC (Role + RoleBinding) is applied. Otherwise, the operator will fail and halt normal operations.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is Multi-Namespace REDB?

**Multi-namespace deployment** allows a single **Redis Enterprise Operator** to manage clusters (REC) and databases (REDB) across **different namespaces**, providing:

✅ **Namespace Isolation**: Separate Redis resources by team, environment, or application  
✅ **Centralized Management**: Single operator manages multiple namespaces  
✅ **Resource Sharing**: Efficient use of cluster resources  
✅ **Flexible RBAC**: Granular permissions per namespace  

### Benefits

| Benefit | Description |
|---------|-------------|
| **Isolation** | Each team/app has its own namespace with isolated REDBs |
| **Security** | RBAC per namespace, limiting access between teams |
| **Organization** | Clear separation between environments (prod, staging, dev) |
| **Efficiency** | Single REC can serve multiple namespaces |
| **Scalability** | Add new namespaces without new operators |

---

## Architecture

### Namespace Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: redis-enterprise (Operator Namespace)    │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - Redis Enterprise Operator                         │   │
│  │  - RedisEnterpriseCluster (REC)                      │   │
│  │  - REC Pods (rec-0, rec-1, rec-2)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           │ Manages                           │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-production (Consumer Namespace)      │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - prod-db          │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-staging (Consumer Namespace)         │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - staging-db       │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-development (Consumer Namespace)     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - dev-db           │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **Operator Namespace** (`redis-enterprise`):
   - Redis Enterprise Operator
   - RedisEnterpriseCluster (REC)
   - REC Pods (cluster nodes)

2. **Consumer Namespaces** (`app-production`, `app-staging`, `app-development`):
   - RedisEnterpriseDatabase (REDB) resources
   - Services (database endpoints)
   - Secrets (credentials)

---

## Prerequisites

### 1. Kubernetes Cluster

```bash
kubectl version --short
# Client Version: v1.28+
# Server Version: v1.28+
```

### 2. Redis Enterprise Operator Installed

The operator must be installed in the `redis-enterprise` namespace:

```bash
kubectl get deployment redis-enterprise-operator -n redis-enterprise
```

### 3. RedisEnterpriseCluster (REC) Created

```bash
kubectl get rec -n redis-enterprise
# NAME   NODES   VERSION    STATE
# rec    3       8.0.6-54   Running
```

### 4. RBAC Permissions

You need permissions to:
- Create namespaces
- Create ClusterRoles and ClusterRoleBindings
- Create Roles and RoleBindings in multiple namespaces

### 5. License Considerations

⚠️ **Important**: Each REDB consumes shards from your license:
- **REDB with replication enabled**: 2 shards (1 master + 1 replica)
- **REDB with replication disabled**: 1 shard

**Free/Trial License Limit**: Typically 4 shards total

**Planning Example**:
```
Production DB (replication: true)   = 2 shards
Staging DB (replication: false)     = 1 shard
Development DB (replication: false) = 1 shard
                                    ─────────
Total                               = 4 shards ✅
```

**Check your current shard usage**:
```bash
kubectl get redb -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SHARDS:.status.shardCount,REPLICATION:.spec.replication
```

---

## Deployment Guide

There are **two methods** to configure multi-namespace support:

- **Method 1: Label-Based** (Recommended, requires operator 6.4.2-4+)
- **Method 2: Explicit Namespace List**

---

### Method 1: Label-Based (Recommended)

This method uses Kubernetes namespace labels to identify which namespaces the operator should manage.

#### Step 1: Create Consumer Namespaces

```bash
# Create namespaces for production, staging, and development
kubectl apply -f 02-consumer-namespaces.yaml
```

This creates three namespaces:
- `app-production`
- `app-staging`
- `app-development`

#### Step 2: Configure RBAC for Consumer Namespaces

⚠️ **CRITICAL**: Apply RBAC **before** configuring operator to watch namespaces.

```bash
# Apply RBAC for operator to manage REDBs in consumer namespaces
kubectl apply -f 03-consumer-rbac.yaml
```

This creates for **each** consumer namespace:
- **Role**: Permissions to manage REDBs, REAADB, Services, Secrets, Events
- **RoleBinding**: Binds Role to:
  - `redis-enterprise-operator` ServiceAccount
  - `rec` ServiceAccount (REC name)

#### Step 3: Configure Operator ClusterRole

```bash
# Apply ClusterRole for operator to list/watch namespaces
kubectl apply -f 01-operator-rbac.yaml
```

This creates:
- **ClusterRole**: Permissions for operator to list/watch namespaces
- **ClusterRoleBinding**: Binds ClusterRole to operator ServiceAccount

#### Step 4: Configure Operator to Watch Labeled Namespaces

```bash
# Patch operator ConfigMap to use label-based watching
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data": {"REDB_NAMESPACES_LABEL": "redis-multi-namespace"}}'
```

⚠️ **Note**: The operator will restart when ConfigMap is updated.

**Verify operator restart**:
```bash
kubectl rollout restart deployment redis-enterprise-operator -n redis-enterprise
kubectl rollout status deployment redis-enterprise-operator -n redis-enterprise --timeout=60s
```

#### Step 5: Label Consumer Namespaces

```bash
# Label each namespace to be managed by operator
kubectl label namespace app-production redis-multi-namespace=enabled
kubectl label namespace app-staging redis-multi-namespace=enabled
kubectl label namespace app-development redis-multi-namespace=enabled
```

⚠️ **Note**: The operator restarts when it detects a namespace label was added or removed.

#### Step 6: Verify Operator Configuration

```bash
# Check operator ConfigMap
kubectl get configmap operator-environment-config -n redis-enterprise -o yaml | grep REDB_NAMESPACES_LABEL

# Check namespace labels
kubectl get namespaces --show-labels | grep redis-multi-namespace

# Check operator logs (should show "watching REDB namespaces: app-development, app-production, app-staging")
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=50 | grep -i "watching REDB namespaces"
```

**Expected output**:
```
{"level":"info","ts":"2025-12-28T19:02:47.604Z","logger":"cmd","msg":"watching REDB namespaces: app-development, app-production, app-staging"}
```

#### Step 7: Deploy REDBs to Consumer Namespaces

⚠️ **Important**: Ensure database ports don't conflict with existing databases. Check current ports:
```bash
kubectl get redb -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PORT:.spec.databasePort
```

**Deploy databases**:

```bash
# Deploy production database (port 12001, replication enabled, 2 shards)
kubectl apply -f 04-redb-production.yaml

# Wait for production database to be active
kubectl wait --for=jsonpath='{.status.status}'=active redb/prod-db -n app-production --timeout=120s

# Deploy staging database (port 12002, replication disabled, 1 shard)
kubectl apply -f 05-redb-staging.yaml

# Wait for staging database to be active
kubectl wait --for=jsonpath='{.status.status}'=active redb/staging-db -n app-staging --timeout=120s

# Deploy development database (port 12003, replication disabled, 1 shard)
kubectl apply -f 06-redb-development.yaml

# Wait for development database to be active
kubectl wait --for=jsonpath='{.status.status}'=active redb/dev-db -n app-development --timeout=120s
```

**Database Configuration Summary**:
| Database | Namespace | Port | Replication | Shards | Memory |
|----------|-----------|------|-------------|--------|--------|
| prod-db | app-production | 12001 | ✅ Enabled | 2 | 2GB |
| staging-db | app-staging | 12002 | ❌ Disabled | 1 | 1GB |
| dev-db | app-development | 12003 | ❌ Disabled | 1 | 512MB |
| **Total** | | | | **4** | **3.5GB** |

#### Step 8: Verify Deployments

```bash
# Check REDBs in all namespaces
kubectl get redb -A

# Expected output:
# NAMESPACE         NAME         VERSION   PORT    CLUSTER   SHARDS   STATUS   SPEC STATUS   AGE
# app-development   dev-db       8.2.1     12003   rec       1        active   Valid         1m
# app-production    prod-db      8.2.1     12001   rec       2        active   Valid         3m
# app-staging       staging-db   8.2.1     12002   rec       1        active   Valid         2m
```

**Verify each database**:
```bash
# Production database
kubectl get redb prod-db -n app-production
kubectl describe redb prod-db -n app-production
kubectl get svc prod-db -n app-production
kubectl get secret redb-prod-db -n app-production

# Staging database
kubectl get redb staging-db -n app-staging
kubectl describe redb staging-db -n app-staging
kubectl get svc staging-db -n app-staging
kubectl get secret redb-staging-db -n app-staging

# Development database
kubectl get redb dev-db -n app-development
kubectl describe redb dev-db -n app-development
kubectl get svc dev-db -n app-development
kubectl get secret redb-dev-db -n app-development
```

#### Step 9: Test Connectivity

**Get database password**:
```bash
# Production database password
PROD_PASSWORD=$(kubectl get secret redb-prod-db -n app-production -o jsonpath='{.data.password}' | base64 -d)
echo "Production DB Password: $PROD_PASSWORD"
```

**Test from within cluster** (recommended):
```bash
# Test PING
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h redis-12001.redis-enterprise.svc.cluster.local -p 12001 \
  --tls --insecure -a "$PROD_PASSWORD" PING

# Expected output: PONG

# Test SET
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h redis-12001.redis-enterprise.svc.cluster.local -p 12001 \
  --tls --insecure -a "$PROD_PASSWORD" SET test:multi-ns "production-value"

# Expected output: OK

# Test GET
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h redis-12001.redis-enterprise.svc.cluster.local -p 12001 \
  --tls --insecure -a "$PROD_PASSWORD" GET test:multi-ns

# Expected output: "production-value"
```

**Test other databases**:
```bash
# Staging database (port 12002)
STAGING_PASSWORD=$(kubectl get secret redb-staging-db -n app-staging -o jsonpath='{.data.password}' | base64 -d)
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h redis-12002.redis-enterprise.svc.cluster.local -p 12002 \
  --tls --insecure -a "$STAGING_PASSWORD" PING

# Development database (port 12003, TLS disabled)
DEV_PASSWORD=$(kubectl get secret redb-dev-db -n app-development -o jsonpath='{.data.password}' | base64 -d)
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h redis-12003.redis-enterprise.svc.cluster.local -p 12003 \
  -a "$DEV_PASSWORD" PING
```

---

### Method 2: Explicit Namespace List

This method uses a comma-separated list of namespaces in the operator ConfigMap.

#### Steps 1-3: Same as Method 1

Follow Steps 1-3 from Method 1 (create namespaces, configure RBAC, configure ClusterRole).

#### Step 4: Configure Operator with Namespace List

```bash
# Patch operator ConfigMap with explicit namespace list
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data":{"REDB_NAMESPACES": "app-production,app-staging,app-development"}}'
```

⚠️ **Note**: The operator will restart when ConfigMap is updated.

#### Steps 5-6: Deploy and Verify

Follow Steps 7-8 from Method 1 (deploy REDBs and verify).

---

### Adding New Namespaces

#### Method 1 (Label-Based):

```bash
# Create new namespace
kubectl create namespace app-testing

# Apply RBAC
kubectl apply -f 03-consumer-rbac.yaml

# Label namespace
kubectl label namespace app-testing redis-multi-namespace=enabled
```

#### Method 2 (Explicit List):

```bash
# Create new namespace
kubectl create namespace app-testing

# Apply RBAC
kubectl apply -f 03-consumer-rbac.yaml

# Update ConfigMap
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data":{"REDB_NAMESPACES": "app-production,app-staging,app-development,app-testing"}}'
```

---

## Use Cases

### Use Case 1: Multi-Environment Deployment

Separate production, staging, and development databases in different namespaces:

- **Production** (`app-production`): High resources, strict RBAC
- **Staging** (`app-staging`): Medium resources, testing environment
- **Development** (`app-development`): Low resources, developer access

### Use Case 2: Multi-Tenant SaaS

Each customer gets their own namespace with isolated databases:

- `customer-a` namespace → `customer-a-db` REDB
- `customer-b` namespace → `customer-b-db` REDB
- `customer-c` namespace → `customer-c-db` REDB

### Use Case 3: Team-Based Isolation

Each team has their own namespace:

- `team-backend` → Backend services databases
- `team-frontend` → Frontend caching databases
- `team-analytics` → Analytics databases

---

## Cleanup

```bash
# Delete REDBs
kubectl delete -f 04-redb-production.yaml
kubectl delete -f 05-redb-staging.yaml
kubectl delete -f 06-redb-development.yaml

# Delete consumer namespaces (this also deletes all resources inside)
kubectl delete -f 02-consumer-namespaces.yaml

# Delete RBAC
kubectl delete -f 03-consumer-rbac.yaml
kubectl delete -f 01-operator-rbac.yaml
```

**Note**: This does NOT delete the REC or operator in `redis-enterprise` namespace.

---

## Troubleshooting

### Issue 1: License Shard Limit Exceeded

**Symptoms**:
```
Error from server: admission webhook "redisenterprise.admission.redislabs" denied the request:
Total shards count exceeds amount of total shards permitted by license.
License permits 4 total shards, but there are 5 total shards in use.
```

**Cause**: Free/trial license typically allows only 4 shards total. Each REDB with replication uses 2 shards.

**Solution**:

**Option 1: Disable replication on non-production databases**
```bash
# Check current shard usage
kubectl get redb -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SHARDS:.status.shardCount,REPLICATION:.spec.replication

# Delete database
kubectl delete redb staging-db -n app-staging

# Edit YAML to set replication: false
# Then reapply
kubectl apply -f 05-redb-staging.yaml
```

**Option 2: Delete unused databases**
```bash
# Delete test databases from other namespaces
kubectl delete redb test-db -n redis-enterprise
```

**Option 3: Upgrade license**
- Contact Redis for production license with more shards

**Planning Guide**:
```
Free License: 4 shards maximum

Configuration A (1 production + 2 non-production):
  prod-db (replication: true)    = 2 shards
  staging-db (replication: false) = 1 shard
  dev-db (replication: false)     = 1 shard
  Total                           = 4 shards ✅

Configuration B (2 production):
  prod-db-1 (replication: true)   = 2 shards
  prod-db-2 (replication: true)   = 2 shards
  Total                           = 4 shards ✅

Configuration C (4 non-production):
  db-1 (replication: false)       = 1 shard
  db-2 (replication: false)       = 1 shard
  db-3 (replication: false)       = 1 shard
  db-4 (replication: false)       = 1 shard
  Total                           = 4 shards ✅
```

### Issue 2: REDB Stuck in Pending State

**Symptoms**:
- REDB remains in pending state indefinitely
- No events on REDB resource

**Possible Causes**:
1. RBAC not configured in consumer namespace
2. Operator not configured to watch the namespace
3. Namespace not labeled (Method 1) or not in list (Method 2)

**Solution**:
```bash
# Check RBAC in consumer namespace
kubectl get role,rolebinding -n app-production

# Check operator ConfigMap
kubectl get configmap operator-environment-config -n redis-enterprise -o yaml

# Check namespace labels (Method 1)
kubectl get namespace app-production --show-labels

# Check operator logs
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

### Issue 2: Operator Crashes or Fails

**Symptoms**:
- Operator pod crashes
- Operator logs show errors about missing permissions

**Possible Causes**:
- Operator configured to watch namespace before RBAC was applied
- Operator configured to watch non-existent namespace

**Solution**:
```bash
# Remove namespace from watch list
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data":{"REDB_NAMESPACES": ""}}'

# Or remove label
kubectl label namespace app-production redis-multi-namespace-

# Apply RBAC
kubectl apply -f 03-consumer-rbac.yaml

# Re-add namespace to watch list
kubectl label namespace app-production redis-multi-namespace=enabled
```

### Issue 3: REDB Created but No Service

**Symptoms**:
- REDB shows as active
- No service created in consumer namespace

**Possible Causes**:
- RoleBinding missing permissions for services

**Solution**:
```bash
# Check RoleBinding
kubectl get rolebinding redb-role -n app-production -o yaml

# Verify operator ServiceAccount has permissions
kubectl auth can-i create services --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator -n app-production
```

### Issue 4: Multi-Namespace Active-Active (REAADB)

**Additional Requirements for REAADB**:
1. All participating clusters must watch the consumer namespace
2. Global database secret must exist in each consumer namespace
3. REAADB must specify `metadata.namespace` and `spec.participatingClusters[].namespace`

**Example**:
```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseActiveActiveDatabase
metadata:
  name: consumer-reaadb
  namespace: app-production  # Consumer namespace
spec:
  participatingClusters:
    - name: rec  # Main cluster
    - name: rec-peer  # Peer cluster
      namespace: app-production  # Must match metadata.namespace
  globalConfigurations:
    databaseSecretName: global-db-secret  # Must exist in app-production
```

For more detailed troubleshooting, see [07-troubleshooting.md](./07-troubleshooting.md).

---

## References

- [Redis Enterprise Operator Documentation](https://docs.redis.com/latest/kubernetes/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

