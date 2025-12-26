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
| `01-rbac-rack-awareness.yaml` | RBAC for multi-AZ rack awareness |
| `02-rec.yaml` | Redis Enterprise Cluster (3 nodes) |
| `03-redb.yaml` | Redis Database (test-db) |

---

## Deployment

```bash
# 1. Create namespace
kubectl apply -f 00-namespace.yaml

# 2. Apply RBAC for rack awareness
kubectl apply -f 01-rbac-rack-awareness.yaml

# 3. Deploy Redis Enterprise Cluster
kubectl apply -f 02-rec.yaml

# 4. Wait for cluster to be ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# 5. Verify cluster
kubectl get rec -n redis-enterprise
kubectl get pods -n redis-enterprise

# 6. Create database
kubectl apply -f 03-redb.yaml

# 7. Wait for database to be ready
kubectl wait --for=condition=Active redb/test-db -n redis-enterprise --timeout=300s

# 8. Verify database
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
- **TLS:** Enabled
- **Replication:** Enabled (master + replica)

---

## Access Credentials

### REC Admin Password

```bash
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

**Default user:** `demo@redis.com`

### Database Password

```bash
kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

---

## Test Connectivity

### Get Database Port

```bash
DB_PORT=$(kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databasePort}')
echo "Database Port: $DB_PORT"
```

### Get Database Password

```bash
DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)
```

### Test Connection (Internal - No TLS)

```bash
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p $DB_PORT -a $DB_PASSWORD PING
```

**Expected:** `PONG`

### Test Connection (With TLS)

```bash
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p $DB_PORT --tls --insecure -a $DB_PASSWORD PING
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

