# In-Cluster Connectivity

This guide covers how applications running **inside the Kubernetes cluster** connect to Redis Enterprise databases.

## Overview

In-cluster connectivity is the **simplest and most common** way to access Redis Enterprise databases. Applications use standard Kubernetes Services to connect to databases.

### Services Created by Operator

The Redis Enterprise Operator automatically creates these services:

| Service | Type | Purpose | Port(s) |
|---------|------|---------|---------|
| `<rec-name>` | ClusterIP | REC API | 9443 (API), 8001 (metrics) |
| `<rec-name>-ui` | ClusterIP | Web UI | 8443 |
| `<rec-name>-prom` | Headless | Prometheus metrics | 8070 |
| `<db-name>` | ClusterIP | Database endpoint | Database port |

**Example from our cluster:**

```bash
$ kubectl get svc -n redis-enterprise
NAME        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
rec         ClusterIP   10.100.32.235    <none>        9443/TCP,8001/TCP   4h56m
rec-ui      ClusterIP   10.100.48.189    <none>        8443/TCP            4h56m
rec-prom    ClusterIP   None             <none>        8070/TCP            4h56m
test-db     ClusterIP   10.100.200.63    <none>        11909/TCP           4h53m
```

---

## DNS Resolution

Services are accessible via DNS within the cluster:

**Full FQDN:**
```
<service-name>.<namespace>.svc.cluster.local
```

**Short form (same namespace):**
```
<service-name>
```

**Examples:**
- Database: `test-db.redis-enterprise.svc.cluster.local:11909` or `test-db:11909`
- REC API: `rec.redis-enterprise.svc.cluster.local:9443` or `rec:9443`
- Web UI: `rec-ui.redis-enterprise.svc.cluster.local:8443` or `rec-ui:8443`

---

## Connection Details

### 1. Get Database Information

```bash
# List all services
kubectl get svc -n redis-enterprise

# Get database port
kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databasePort}'

# Get database password
kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 --decode
```

### 2. Connection String Format

**Without TLS:**
```
redis://default:<password>@<db-name>.<namespace>.svc.cluster.local:<port>
```

**With TLS:**
```
rediss://default:<password>@<db-name>.<namespace>.svc.cluster.local:<port>
```

**Example:**
```
redis://default:mypassword@test-db.redis-enterprise.svc.cluster.local:11909
```

---

## Quick Connection Test

Test connectivity using a temporary pod:

```bash
# Get database password
DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 --decode)

# Run temporary redis-cli pod
kubectl run redis-test --rm -it --restart=Never \
  --image=redis:7-alpine \
  -n redis-enterprise \
  -- redis-cli -h test-db -p 11909 -a "$DB_PASSWORD"
```

**Test commands:**
```redis
PING
SET mykey "Hello from Kubernetes!"
GET mykey
INFO server
```

---

## Application Configuration

Your applications running in the cluster should use environment variables for configuration:

**Example Deployment:**

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

## Service Types Explained

### ClusterIP (Default)

Database services use **ClusterIP** which provides:
- ✅ Stable internal IP address
- ✅ Load balancing across database shards
- ✅ Only accessible within the cluster

### Headless (Prometheus)

The `<rec-name>-prom` service is **headless** (ClusterIP: None):
- Returns pod IPs directly (no virtual IP)
- Used by Prometheus for service discovery
- Allows direct pod-to-pod communication

---

## Next Steps

- **External Access**: See [../gateway-api/](../gateway-api/) for exposing databases outside the cluster
- **Gateway API**: Modern way to route external traffic to databases
- **Ingress (Legacy)**: See [../ingress/](../ingress/) for legacy ingress controllers

---

## Troubleshooting

### Cannot resolve service name

**Problem:** `could not resolve host: test-db`

**Solution:** Use FQDN or verify DNS:

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -n redis-enterprise \
  -- nslookup test-db.redis-enterprise.svc.cluster.local
```

### Connection refused

**Problem:** `Connection refused` or `timeout`

**Solution:** Verify service and pods:

```bash
kubectl get svc test-db -n redis-enterprise
kubectl get pods -n redis-enterprise -l app=redis-enterprise
```

### Authentication failed

**Problem:** `NOAUTH Authentication required`

**Solution:** Verify password:

```bash
kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 --decode
```

