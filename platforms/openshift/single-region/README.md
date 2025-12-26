# OpenShift Single-Region Deployment

Complete example for deploying Redis Enterprise on OpenShift with platform-specific configurations.

---

## Overview

This directory contains **OpenShift-specific** deployment examples that include:
- Pre-configured secrets (admin and database passwords)
- REC with OpenShift Routes integration
- REDB with pre-defined password
- OpenShift-specific image repositories (Red Hat registry)

**For generic deployment** (works on any platform), see: [../../../deployments/single-region/](../../../deployments/single-region/)

---

## Files

```
platforms/openshift/single-region/
├── README.md                    # This file
├── 00-namespace.yaml            # Namespace (redis-ns-a)
├── 01-rec-admin-secret.yaml     # REC admin credentials (pre-defined)
├── 02-rec.yaml                  # REC with OpenShift Routes
├── 03-redb-secret.yaml          # Database password (pre-defined)
└── 04-redb.yaml                 # Database configuration
```

**Note:** Routes are in [../routes/](../routes/)

---

## Prerequisites

- OpenShift cluster (4.10+)
- `oc` CLI configured
- Redis Enterprise Operator installed (see [../../../operator/README.md](../../../operator/README.md))
- SCC configured (see [../scc/README.md](../scc/README.md))

---

## Quick Start

### 1. Apply SCC (OpenShift-Specific)

**See:** [../scc/README.md](../scc/README.md)

```bash
oc apply -f ../scc/redis-scc.yaml
```

### 2. Deploy Namespace and Secrets

```bash
# Create namespace
oc apply -f 00-namespace.yaml

# Create REC admin secret (username: admin@redis.com, password: RedisAdmin123!)
oc apply -f 01-rec-admin-secret.yaml

# Create database password secret (password: RedisAdmin123!)
oc apply -f 03-redb-secret.yaml
```

### 3. Deploy REC

```bash
# Deploy REC with OpenShift Routes
oc apply -f 02-rec.yaml

# Wait for ready (5-10 min)
oc wait --for=condition=Ready rec/rec -n redis-ns-a --timeout=600s

# Check status
oc get rec -n redis-ns-a
```

### 4. Deploy Database

```bash
# Create database
oc apply -f 04-redb.yaml

# Check status
oc get redb -n redis-ns-a
```

### 5. Configure Routes (OpenShift-Specific)

**See:** [../routes/README.md](../routes/README.md)

```bash
# Apply routes
oc apply -f ../routes/route-ui.yaml
oc apply -f ../routes/route-db.yaml

# Get URLs
oc get routes -n redis-ns-a
```

---

## Configuration Details

### Namespace

**File:** `00-namespace.yaml`

Uses `redis-ns-a` (common in OpenShift examples).

### REC Admin Secret

**File:** `01-rec-admin-secret.yaml`

Pre-configured credentials:
- **Username:** `admin@redis.com`
- **Password:** `RedisAdmin123!`

**⚠️ IMPORTANT:** Change password before production deployment!

### REC Configuration

**File:** `02-rec.yaml`

OpenShift-specific features:
- **Routes Integration:** `method: openShiftRoute`
- **Red Hat Registry:** Uses `registry.connect.redhat.com/redislabs/*` images
- **FQDN Configuration:** Requires cluster-specific FQDNs
- **Resources:** 2 CPU / 4Gi memory per node

**⚠️ IMPORTANT:** Update FQDNs (`apiFqdnUrl` and `dbFqdnSuffix`) to match your OpenShift cluster!

### Database Secret

**File:** `03-redb-secret.yaml`

Pre-configured password:
- **Password:** `RedisAdmin123!`

**⚠️ IMPORTANT:** Change password before production deployment!

### Database Configuration

**File:** `04-redb.yaml`

Standard database configuration with:
- **Size:** 1GB
- **TLS:** Enabled
- **Replication:** Enabled
- **Password:** From secret `redb-secret`

---

## Access REC UI

```bash
# Get Route URL
UI_URL=$(oc get route rec-ui -n redis-ns-a -o jsonpath='{.spec.host}')

echo "REC UI: https://$UI_URL"

# Login with:
# Username: admin@redis.com
# Password: RedisAdmin123!
```

---

## Access Database

```bash
# Get database Route
DB_HOST=$(oc get route redb-route -n redis-ns-a -o jsonpath='{.spec.host}')
DB_PORT=443  # Routes use 443

# Get password
DB_PASSWORD=$(oc get secret redb-secret -n redis-ns-a -o jsonpath='{.data.password}' | base64 -d)

# Test connection
oc run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h $DB_HOST -p $DB_PORT --tls --insecure --sni $DB_HOST -a $DB_PASSWORD PING
```

---

## Differences from Generic Deployment

| Feature | Generic | OpenShift-Specific |
|---------|---------|-------------------|
| **Namespace** | `redis-enterprise` | `redis-ns-a` |
| **Secrets** | Auto-generated | Pre-defined |
| **Routes** | Not included | Included (`ingressOrRouteSpec`) |
| **Images** | Docker Hub | Red Hat Registry |
| **FQDNs** | Not required | Required for Routes |
| **SCC** | Not required | Required |

---

## Troubleshooting

### REC Not Starting

```bash
# Check events
oc get events -n redis-ns-a --sort-by='.lastTimestamp'

# Check SCC
oc get scc redis-scc

# Check pods
oc get pods -n redis-ns-a
```

### Routes Not Working

```bash
# Check routes
oc get routes -n redis-ns-a

# Verify FQDNs in REC match cluster domain
oc get rec rec -n redis-ns-a -o yaml | grep -A 5 ingressOrRouteSpec
```

---

## References

- [Generic Deployment](../../../deployments/single-region/README.md)
- [OpenShift Routes](../routes/README.md)
- [OpenShift SCC](../scc/README.md)
- [Redis Enterprise on OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)

