# In-Cluster Connectivity

Applications inside the cluster connect to Redis databases via Kubernetes Services.

---

## Services

Operator creates these services automatically:

| Service | Type | Port(s) |
|---------|------|---------|
| `<rec-name>` | ClusterIP | 9443 (API), 8001 (metrics) |
| `<rec-name>-ui` | ClusterIP | 8443 (UI) |
| `<rec-name>-prom` | Headless | 8070 (Prometheus) |
| `<db-name>` | ClusterIP | Database port |

---

## DNS

**FQDN:**
```
<service-name>.<namespace>.svc.cluster.local
```

**Short (same namespace):**
```
<service-name>
```

**Examples:**
- `test-db.redis-enterprise.svc.cluster.local:11909`
- `test-db:11909` (same namespace)

---

## Connection

### Get Database Info

```bash
# Port
kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databasePort}'

# Password
kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

### Connection String

```
redis://default:<password>@<db-name>.<namespace>.svc.cluster.local:<port>
```

### Test

```bash
kubectl run redis-test --rm -it --restart=Never \
  --image=redis:7-alpine \
  -n redis-enterprise \
  -- redis-cli -h test-db -p 11909 PING
```

---

## Application Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-app:latest
        env:
        - name: REDIS_HOST
          value: "test-db.redis-enterprise.svc.cluster.local"
        - name: REDIS_PORT
          value: "11909"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redb-test-db
              key: password
```

---

## Troubleshooting

```bash
# Verify service
kubectl get svc test-db -n redis-enterprise

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n redis-enterprise \
  -- nslookup test-db

# Check password
kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```
