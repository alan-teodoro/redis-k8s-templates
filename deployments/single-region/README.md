# Single-Region Redis Enterprise Deployment

Generic deployment for Redis Enterprise Cluster and Database in a single Kubernetes cluster.

**Works on:** EKS, GKE, AKS, OpenShift, Vanilla Kubernetes

---

## Prerequisites

- Kubernetes cluster running
- Redis Enterprise Operator installed ([operator/README.md](../../operator/README.md))
- Storage configured (see your platform's README)
- Namespace created

---

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Namespace creation |
| `01-rec-admin-secret.yaml` | REC admin credentials (username: admin@redis.com, password: RedisAdmin123!) |
| `02-redb-secret.yaml` | Database password (RedisAdmin123!) |
| `03-rbac-rack-awareness.yaml` | RBAC for multi-AZ rack awareness |
| `04-rec.yaml` | Redis Enterprise Cluster (3 nodes) |
| `05-redb.yaml` | Redis Database (test-db, port 12000) |

**⚠️ IMPORTANT:** Change passwords before production deployment!

---

## Deployment

```bash
# 1. Create namespace
kubectl apply -f 00-namespace.yaml

# 2. Create secrets (admin: admin@redis.com / RedisAdmin123!, db: RedisAdmin123!)
kubectl apply -f 01-rec-admin-secret.yaml
kubectl apply -f 02-redb-secret.yaml

# 3. Apply RBAC for rack awareness
kubectl apply -f 03-rbac-rack-awareness.yaml

# 4. Deploy Redis Enterprise Cluster
kubectl apply -f 04-rec.yaml

# 5. Wait for cluster to be ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# 6. Verify cluster
kubectl get rec -n redis-enterprise
kubectl get pods -n redis-enterprise

# 7. Create database (port 12000)
kubectl apply -f 05-redb.yaml

# 8. Wait for database to be ready
kubectl wait --for=condition=Active redb/test-db -n redis-enterprise --timeout=300s

# 9. Verify database
kubectl get redb test-db -n redis-enterprise
```

---

## Configuration Details

### Redis Enterprise Cluster (REC)

- **Nodes:** 3 (for high availability)
- **CPU:** 1 core per node
- **Memory:** 4Gi per node
- **Storage:** 10Gi per node
- **Rack Awareness:** Enabled (distributes across availability zones)

### Redis Database (REDB)

- **Name:** test-db
- **Type:** Redis
- **Memory:** 1GB
- **Port:** 12000 (fixed for consistency)
- **TLS:** Enabled
- **Replication:** Enabled (master + replica)
- **Password:** From secret `redb-secret`

---

## Access Credentials

**Pre-configured credentials for testing/demo purposes:**

### REC Admin Credentials

- **Username:** `admin@redis.com`
- **Password:** `RedisAdmin123!`

```bash
# Get password from secret
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

### Database Password

- **Password:** `RedisAdmin123!`

```bash
# Get password from secret
kubectl get secret redb-secret -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

**⚠️ SECURITY WARNING:** These are default credentials for testing/demo purposes only. **ALWAYS change passwords before production deployment!**

---

## Test Connectivity

### Connection Details

```bash
# Database endpoint
DB_HOST=test-db.redis-enterprise.svc.cluster.local
DB_PORT=12000  # Fixed port for consistency

# Get password
DB_PASSWORD=$(kubectl get secret redb-secret -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)
# Or use default: RedisAdmin123!
```

### Test Connection (With TLS - Recommended)

```bash
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 12000 --tls --insecure -a RedisAdmin123! PING
```

**Expected:** `PONG`

### Test Connection (Internal - No TLS)

```bash
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 12000 -a RedisAdmin123! PING
```

**Expected:** `PONG`

---

## Next Steps

### External Access

Choose networking solution based on your platform:

- **Generic (EKS/GKE/AKS/Vanilla):** [networking/gateway-api/nginx-gateway-fabric/README.md](../../networking/gateway-api/nginx-gateway-fabric/README.md)
- **OpenShift:** [platforms/openshift/routes/README.md](../../platforms/openshift/routes/README.md)

### Monitoring

**See:** [monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

### Backup/Restore

**See:** [backup-restore/README.md](../../backup-restore/README.md)

---

## Troubleshooting

### Cluster Not Ready

```bash
# Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50

# Check REC status
kubectl describe rec rec -n redis-enterprise

# Check pod events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'
```

### Database Not Active

```bash
# Check database status
kubectl describe redb test-db -n redis-enterprise

# Check REC logs
kubectl logs -n redis-enterprise rec-0 -c redis-enterprise-node --tail=50
```

### Storage Issues

Verify storage class is available and set as default:

```bash
kubectl get storageclass
```

See your platform's storage documentation for details.

