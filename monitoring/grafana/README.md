# Grafana Dashboards for Redis Enterprise

Grafana dashboards for visualizing Redis Enterprise metrics.

**Platform-agnostic:** Works on EKS, GKE, AKS, OpenShift, and vanilla Kubernetes.

## 📋 Available Dashboards

- **redis-enterprise-overview.json** - Cluster health, nodes, databases, operations/sec

## 🚀 Import Dashboard

### Via Grafana UI

1. Access Grafana:
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   # Open: http://localhost:3000
   # User: admin
   # Password: prom-operator
   ```

2. Import dashboard:
   - Click **"+"** → **"Import"**
   - Upload `dashboards/redis-enterprise-overview.json`
   - Select **Prometheus** data source
   - Click **"Import"**

### Via ConfigMap (Auto-load)

For automatic dashboard loading:

```bash
kubectl create configmap grafana-dashboard-redis-overview \
  --from-file=redis-enterprise-overview.json=dashboards/redis-enterprise-overview.json \
  -n monitoring

kubectl label configmap grafana-dashboard-redis-overview \
  grafana_dashboard=1 \
  -n monitoring
```

Grafana will automatically discover and load the dashboard.

---

## 📊 Key Metrics (v2)

### Cluster Health

```promql
# Nodes up
count(node_metrics_up == 1)

# Cluster has quorum
has_quorum

# Total cluster memory
sum(node_memory_MemTotal_bytes)
```

### Database Performance

```promql
# Operations/sec
rate(bdb_total_req[5m])

# Memory usage %
(bdb_used_memory / bdb_memory_limit) * 100

# Hit rate %
rate(bdb_keyspace_hits[5m]) / (rate(bdb_keyspace_hits[5m]) + rate(bdb_keyspace_misses[5m])) * 100

# Connections
bdb_conns

# Evicted keys
rate(bdb_evicted_objects[5m])
```

### Active-Active Metrics

```promql
# Replication lag
bdb_crdt_syncer_local_ingress_lag_time

# Replication traffic (bytes/sec)
rate(bdb_crdt_syncer_ingress_bytes_decompressed[5m])

# Syncer status (1 = healthy)
bdb_crdt_syncer_status
```

---

## 🔍 Troubleshooting

### Verify Metrics in Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open: http://localhost:9090
# Query examples:
# - node_metrics_up
# - bdb_total_req
# - has_quorum
```

### Check ServiceMonitor

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor redis-enterprise-cluster -n monitoring

# Check targets in Prometheus UI
# Go to: http://localhost:9090/targets
# Look for: redis-enterprise-cluster
```

### Dashboard Not Showing Data

1. **Check Prometheus data source:**
   - Grafana → Configuration → Data Sources
   - Verify Prometheus URL: `http://kube-prometheus-stack-prometheus.monitoring:9090`

2. **Verify metrics exist:**
   - Go to Prometheus UI
   - Run query: `node_metrics_up`
   - Should return results

3. **Check time range:**
   - Ensure dashboard time range includes recent data
   - Try "Last 5 minutes"

---

## 📚 References

- [Redis Enterprise Prometheus Metrics v2](https://redis.io/docs/latest/operate/rs/references/metrics/prometheus-metrics-v2/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
