# Grafana Dashboards for Redis Enterprise

## Available Dashboards

- **redis-enterprise-overview.json** - Cluster health, nodes, databases, operations/sec

---

## Import Dashboard

### Via Grafana UI

1. Login to Grafana
2. **"+"** → **"Import"**
3. Upload `dashboards/redis-enterprise-overview.json`
4. Select **Prometheus** data source
5. **"Import"**

### Via ConfigMap (Auto-load)

```bash
kubectl create configmap grafana-dashboard-redis-overview \
  --from-file=redis-enterprise-overview.json=dashboards/redis-enterprise-overview.json \
  -n monitoring

kubectl label configmap grafana-dashboard-redis-overview \
  grafana_dashboard=1 \
  -n monitoring
```

---

## Key Metrics

```promql
# Cluster nodes up
count(up{job="redis-enterprise-cluster"} == 1)

# Database operations/sec
rate(redis_db_total_req[5m])

# Memory usage %
(redis_db_used_memory / redis_db_memory_limit) * 100

# Hit rate %
(rate(redis_db_keyspace_hits[5m]) / (rate(redis_db_keyspace_hits[5m]) + rate(redis_db_keyspace_misses[5m]))) * 100
```

---

## Troubleshooting

```bash
# Check if metrics exist in Prometheus
# Go to: http://localhost:9090
# Query: up{job="redis-enterprise-cluster"}
```

---

## References

- [Redis Enterprise Metrics](https://docs.redis.com/latest/rs/clusters/monitoring/prometheus-metrics-definitions/)
