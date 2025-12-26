# Prometheus Monitoring for Redis Enterprise

Prometheus and Grafana monitoring configuration for Redis Enterprise on Kubernetes.

**Platform-agnostic:** Works on EKS, GKE, AKS, OpenShift, and vanilla Kubernetes.

## 📋 Overview

This configuration provides:
- **Metrics collection** from Redis Enterprise Cluster and databases
- **Pre-configured alerts** for common issues
- **Grafana dashboards** for visualization
- **ServiceMonitor** for automatic Prometheus scraping

### Metrics Version

Uses **Prometheus Metrics v2** (Redis Enterprise 8.0+):
- Endpoint: `https://<rec-name>-prom:8070/v2`
- Includes cluster, database, node, and shard metrics
- Also exposes node_exporter v1.8.1 metrics

For Redis Enterprise 7.x (metrics v1), remove `path: /v2` from ServiceMonitor.

## 🚀 Installation

### Step 1: Install kube-prometheus-stack

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with custom values
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f values.yaml
```

### Step 2: Apply ServiceMonitor

```bash
kubectl apply -f servicemonitors/redis-enterprise.yaml
```

### Step 3: Apply PrometheusRules (Alerts)

```bash
kubectl apply -f prometheusrules/redis-enterprise-alerts.yaml
```

---

## Access

### Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090
```

### Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000
# User: admin
# Password: prom-operator
```

Import dashboard: `dashboards/redis-enterprise-overview.json`

---

## Verify Metrics

```bash
# Check ServiceMonitor
kubectl get servicemonitor redis-enterprise-cluster -n monitoring

# Check targets in Prometheus
# Go to: http://localhost:9090/targets
# Look for: redis-enterprise-cluster

# Verify metrics are being scraped
kubectl get --raw /api/v1/namespaces/redis-enterprise/services/rec-prom:prometheus/proxy/v2 | head -20
```

---

## Key Metrics (v2)

### Cluster Metrics

```promql
# Node status (1 = up, 0 = down)
node_metrics_up

# Cluster quorum (1 = has quorum, 0 = lost quorum)
has_quorum

# Total memory available
node_memory_MemTotal_bytes

# Free memory
node_memory_MemFree_bytes
```

### Database Metrics

```promql
# Database operations/sec
rate(bdb_total_req[5m])

# Database memory usage
bdb_used_memory

# Database connections
bdb_conns

# Replication lag (Active-Active)
bdb_crdt_syncer_ingress_bytes_decompressed

# Hit rate
rate(bdb_keyspace_hits[5m]) / (rate(bdb_keyspace_hits[5m]) + rate(bdb_keyspace_misses[5m]))
```

### Shard Metrics

```promql
# Shard CPU usage
redis_process_cpu_usage_percent

# Shard memory
redis_used_memory

# Commands/sec per shard
rate(redis_total_commands_processed[5m])
```

---

## Monitoring Active-Active Deployments

For Active-Active (multi-region) deployments, monitor both clusters:

```bash
# Apply ServiceMonitor on both clusters
kubectl apply -f servicemonitors/redis-enterprise.yaml --context=cluster-a
kubectl apply -f servicemonitors/redis-enterprise.yaml --context=cluster-b

# Apply alerts on both clusters
kubectl apply -f prometheusrules/redis-enterprise-alerts.yaml --context=cluster-a
kubectl apply -f prometheusrules/redis-enterprise-alerts.yaml --context=cluster-b
```

**Key Active-Active metrics:**
- `bdb_crdt_syncer_ingress_bytes_decompressed` - Replication traffic
- `bdb_crdt_syncer_local_ingress_lag_time` - Replication lag
- `bdb_crdt_syncer_status` - Syncer status (1 = healthy)

---

## Troubleshooting

```bash
# Check ServiceMonitor status
kubectl describe servicemonitor redis-enterprise-cluster -n redis-enterprise

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=50

# Verify service exists
kubectl get svc rec-prom -n redis-enterprise
```

---

## References

- [Redis Enterprise Metrics](https://docs.redis.com/latest/rs/clusters/monitoring/prometheus-metrics-definitions/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

