# Prometheus Monitoring for Redis Enterprise

## Installation

### 1. Install kube-prometheus-stack

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f values.yaml
```

### 2. Apply ServiceMonitor

```bash
kubectl apply -f servicemonitors/redis-enterprise.yaml
```

### 3. Apply PrometheusRules (Alerts)

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
kubectl get servicemonitor redis-enterprise-cluster -n redis-enterprise

# Check targets in Prometheus
# Go to: http://localhost:9090/targets
# Look for: redis-enterprise-cluster
```

---

## Key Metrics

```promql
# Cluster nodes up
redis_cluster_nodes_up

# Database operations/sec
rate(redis_db_total_req[5m])

# Memory usage
redis_db_used_memory_bytes

# Replication lag
redis_db_replication_lag_seconds
```

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

