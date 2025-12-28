# Common LogQL Queries for Redis Enterprise

Use these queries in Grafana Explore or dashboards.

## 🚀 Quick Start

**Access Grafana:**
```bash
kubectl port-forward -n logging svc/loki-grafana 3000:80
# Open: http://localhost:3000
# Navigate to: Explore → Select Loki data source
```

---

## 📊 Basic Queries

### All logs from redis-enterprise namespace
```logql
{namespace="redis-enterprise"}
```

### Logs from specific pod
```logql
{namespace="redis-enterprise", pod="rec-0"}
```

### Logs from specific container
```logql
{namespace="redis-enterprise", container="redis-enterprise"}
```

### Logs from all Redis Enterprise pods
```logql
{namespace="redis-enterprise", app="redis-enterprise"}
```

---

## ⚠️ Error and Warning Queries

### All errors
```logql
{namespace="redis-enterprise"} |= "ERROR"
```

### All warnings
```logql
{namespace="redis-enterprise"} |= "WARN"
```

### Errors and warnings combined
```logql
{namespace="redis-enterprise"} |~ "ERROR|WARN"
```

### Critical errors only
```logql
{namespace="redis-enterprise"} |= "CRITICAL"
```

---

## 💾 Database Operations

### Database creation logs
```logql
{namespace="redis-enterprise"} |= "database" |= "created"
```

### Database deletion logs
```logql
{namespace="redis-enterprise"} |= "database" |= "deleted"
```

### Database backup operations
```logql
{namespace="redis-enterprise"} |= "backup"
```

### Database restore operations
```logql
{namespace="redis-enterprise"} |= "restore"
```

### Replication lag warnings
```logql
{namespace="redis-enterprise"} |= "replication" |= "lag"
```

---

## 🔧 Cluster Operations

### Node join/leave events
```logql
{namespace="redis-enterprise"} |~ "node.*joined|node.*left"
```

### Cluster configuration changes
```logql
{namespace="redis-enterprise"} |= "cluster" |= "config"
```

### Failover events
```logql
{namespace="redis-enterprise"} |= "failover"
```

### Shard migration
```logql
{namespace="redis-enterprise"} |= "shard" |= "migration"
```

---

## 🔐 Authentication and Security

### Failed authentication attempts
```logql
{namespace="redis-enterprise"} |= "authentication" |= "failed"
```

### TLS/SSL errors
```logql
{namespace="redis-enterprise"} |~ "TLS|SSL" |= "error"
```

### Certificate expiration warnings
```logql
{namespace="redis-enterprise"} |= "certificate" |~ "expir"
```

---

## 📈 Performance and Resource Usage

### High memory usage warnings
```logql
{namespace="redis-enterprise"} |= "memory" |~ "high|limit"
```

### CPU throttling
```logql
{namespace="redis-enterprise"} |= "CPU" |= "throttl"
```

### Slow operations
```logql
{namespace="redis-enterprise"} |= "slow"
```

### OOM (Out of Memory) events
```logql
{namespace="redis-enterprise"} |= "OOM"
```

---

## 💾 Backup and Restore

### Backup started
```logql
{namespace="redis-enterprise"} |= "backup" |= "started"
```

### Backup completed
```logql
{namespace="redis-enterprise"} |= "backup" |= "completed"
```

### Backup failed
```logql
{namespace="redis-enterprise"} |= "backup" |= "failed"
```

### Restore operations
```logql
{namespace="redis-enterprise"} |= "restore"
```

---

## 🔍 Advanced Queries with Aggregations

### Error rate (errors per minute)
```logql
rate({namespace="redis-enterprise"} |= "ERROR" [5m])
```

### Top 10 pods by log volume
```logql
topk(10, sum by (pod) (count_over_time({namespace="redis-enterprise"}[1h])))
```

### Parse JSON logs and filter by level
```logql
{namespace="redis-enterprise"} | json | level="error"
```

---

## 📊 Time-based Queries

### Logs from last 5 minutes
```logql
{namespace="redis-enterprise"} [5m]
```

### Logs from last hour
```logql
{namespace="redis-enterprise"} [1h]
```

---

## 🚨 Alerting Queries

Use these in Grafana alerts or Prometheus rules.

### High error rate (> 10 errors/min)
```logql
sum(rate({namespace="redis-enterprise"} |= "ERROR" [1m])) > 10
```

### Database unavailable
```logql
{namespace="redis-enterprise"} |= "database" |= "unavailable"
```

### Cluster not healthy
```logql
{namespace="redis-enterprise"} |= "cluster" |~ "unhealthy|degraded"
```

---

## 💡 Tips

1. **Use label filters first** for better performance:
   ```logql
   {namespace="redis-enterprise", pod="rec-0"} |= "ERROR"
   ```

2. **Combine filters** for precise results:
   ```logql
   {namespace="redis-enterprise"} |= "database" |= "backup" |= "failed"
   ```

3. **Use regex** for complex patterns:
   ```logql
   {namespace="redis-enterprise"} |~ "ERROR|CRITICAL|FATAL"
   ```

4. **Aggregate over time** for trends:
   ```logql
   sum(rate({namespace="redis-enterprise"} |= "ERROR" [5m])) by (pod)
   ```

---

## 📚 Related Documentation

- [Loki Installation](./README.md)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)

