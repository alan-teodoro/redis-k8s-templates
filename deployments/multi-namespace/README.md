# Multi-Namespace REDB Deployment

⚠️ **IMPORTANT LIMITATION - NOT SUPPORTED**

**This deployment pattern is NOT currently supported by the Redis Enterprise Operator.**

The Redis Enterprise Operator (as of version 8.0.6-8, December 2025) **does not support managing REDBs across multiple namespaces**. The operator can only watch and manage resources in a single namespace (configured via `WATCH_NAMESPACE` environment variable).

**Attempting to deploy REDBs in namespaces other than the operator's namespace will result in:**
- REDBs remaining in pending state indefinitely
- No events or status updates on REDB resources
- Operator crashes if `WATCH_NAMESPACE` is set to empty string

---

## Alternative Approaches

If you need namespace isolation for Redis databases, consider these alternatives:

### Option 1: Multiple Operator Instances (Recommended)
Deploy a separate Redis Enterprise Operator and REC in each namespace that needs Redis databases.

**Pros:**
- Full isolation between namespaces
- Each namespace has its own operator and cluster
- Supported configuration

**Cons:**
- Higher resource usage (multiple operators and RECs)
- More complex management

### Option 2: Use Labels and RBAC
Deploy all REDBs in the same namespace (`redis-enterprise`) but use:
- Kubernetes labels to organize databases by team/environment
- RBAC to control access to specific REDB resources
- Naming conventions (e.g., `team-a-prod-db`, `team-b-staging-db`)

**Pros:**
- Single operator and REC
- Lower resource usage
- Simpler management

**Cons:**
- No namespace-level isolation
- All databases in same namespace

---

## Historical Context (For Reference Only)

The content below describes the **intended** multi-namespace deployment pattern, which is **NOT currently functional** with Redis Enterprise Operator. This documentation is preserved for reference in case future operator versions add this capability.

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

---

## Deployment Guide

### Step 1: Configure RBAC for Multi-Namespace

```bash
# Apply RBAC for operator to manage multiple namespaces
kubectl apply -f 01-operator-rbac.yaml
```

This creates:
- **ClusterRole**: Permissions for operator to list namespaces
- **ClusterRoleBinding**: Binds ClusterRole to operator ServiceAccount

### Step 2: Create Consumer Namespaces

```bash
# Create namespaces for production, staging, and development
kubectl apply -f 02-consumer-namespaces.yaml
```

This creates three namespaces:
- `app-production`
- `app-staging`
- `app-development`

### Step 3: Configure RBAC for Consumer Namespaces

```bash
# Apply RBAC for operator to manage REDBs in consumer namespaces
kubectl apply -f 03-consumer-rbac.yaml
```

This creates for EACH consumer namespace:
- **Role**: Permissions to manage REDBs, Services, Secrets
- **RoleBinding**: Binds Role to operator ServiceAccount

### Step 4: Deploy REDBs to Consumer Namespaces

```bash
# Deploy production database
kubectl apply -f 04-redb-production.yaml

# Deploy staging database
kubectl apply -f 05-redb-staging.yaml

# Deploy development database
kubectl apply -f 06-redb-development.yaml
```

### Step 5: Verify Deployments

```bash
# Check REDBs in all namespaces
kubectl get redb -A

# Check production database
kubectl get redb prod-db -n app-production
kubectl get svc prod-db -n app-production

# Check staging database
kubectl get redb staging-db -n app-staging
kubectl get svc staging-db -n app-staging

# Check development database
kubectl get redb dev-db -n app-development
kubectl get svc dev-db -n app-development
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

See [07-troubleshooting.md](./07-troubleshooting.md) for common issues and solutions.

---

## References

- [Redis Enterprise Operator Documentation](https://docs.redis.com/latest/kubernetes/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

