# Basic Redis Enterprise Deployment

## Prerequisites

- Kubernetes cluster (1.23+)
- kubectl configured
- Default StorageClass configured
- Redis Enterprise Operator installed

---

## Deploy

### 1. RBAC for Rack Awareness

```bash
kubectl apply -f rbac-rack-awareness.yaml
```

### 2. Redis Enterprise Cluster

```bash
kubectl apply -f rec-basic.yaml

# Wait for ready (~5 min)
kubectl wait --for=condition=ready rec/rec -n redis-enterprise --timeout=600s
```

### 3. Test Database

```bash
kubectl apply -f redb-test.yaml

# Wait for ready
kubectl wait --for=condition=ready redb/test-db -n redis-enterprise --timeout=300s
```

---

## Verify

```bash
# Cluster status
kubectl get rec -n redis-enterprise
kubectl describe rec rec -n redis-enterprise

# Database status
kubectl get redb test-db -n redis-enterprise

# Get admin password
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
echo
```

---

## Test Connectivity

```bash
# Get database port
DB_PORT=$(kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databasePort}')
echo "Database Port: $DB_PORT"

# Get database password
DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

# Test database (internal - no TLS)
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p $DB_PORT -a $DB_PASSWORD PING

# Test database (with TLS enabled)
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p $DB_PORT --tls --insecure -a $DB_PASSWORD PING
```

---

## Access UI

```bash
# Port-forward
kubectl port-forward -n redis-enterprise svc/rec-ui 8443:8443

# Open: https://localhost:8443
# Username: demo@redis.com
# Password: (from secret above)
```

---

## Troubleshooting

```bash
# Cluster logs
kubectl logs -n redis-enterprise rec-0 -c redis-enterprise-node --tail=50

# Operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50

# Events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'
```

