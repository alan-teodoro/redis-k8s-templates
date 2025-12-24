# Redis Enterprise Monitoring on OpenShift

This directory contains configurations for monitoring Redis Enterprise using OpenShift's built-in Prometheus and Grafana.

## 📋 Overview

Redis Enterprise exposes Prometheus-compatible metrics that can be scraped by OpenShift's monitoring stack. This enables:
- Real-time performance monitoring
- Historical metrics analysis
- Alerting on critical conditions
- Capacity planning

## 🚀 Quick Setup

### Step 1: Enable User Workload Monitoring

OpenShift's user workload monitoring must be enabled to monitor custom applications.

```bash
# Apply the cluster monitoring config
# This enables user workload monitoring cluster-wide
oc apply -f servicemonitor.yaml
```

**Note:** The ConfigMap in `servicemonitor.yaml` enables monitoring for all user workloads. This is a one-time cluster-wide configuration.

### Step 2: Deploy ServiceMonitor

The ServiceMonitor tells Prometheus where to scrape Redis Enterprise metrics.

**Before applying, update the namespace:**

Edit `servicemonitor.yaml` and replace `redis-ns-a` with your actual namespace:
```yaml
metadata:
  namespace: redis-ns-a   # Change this
spec:
  namespaceSelector:
    matchNames:
      - redis-ns-a        # Change this
```

Then apply:
```bash
oc apply -f servicemonitor.yaml
```

### Step 3: Verify Metrics Collection

```bash
# Check ServiceMonitor status
oc get servicemonitor -n redis-ns-a

# Verify Prometheus is scraping
oc get pods -n openshift-user-workload-monitoring
```

## 📊 Accessing Metrics

### OpenShift Console

1. Navigate to **Observe** → **Metrics**
2. Select your namespace (e.g., `redis-ns-a`)
3. Enter PromQL queries (see examples below)

**Note:** Redis Enterprise uses Prometheus v2 metrics. For a complete list of available metrics and their PromQL equivalents, see:
- [Prometheus Metrics v2 Documentation](https://redis.io/docs/latest/integrate/prometheus-with-redis-enterprise/prometheus-metrics-v1-to-v2/)

### Example Queries

**Memory Usage:**
```promql
redis_used_memory_bytes{namespace="redis-ns-a"}
```

**Operations Per Second:**
```promql
rate(redis_commands_processed_total{namespace="redis-ns-a"}[5m])
```

**Connected Clients:**
```promql
redis_connected_clients{namespace="redis-ns-a"}
```

**Cache Hit Ratio:**
```promql
rate(redis_keyspace_hits_total{namespace="redis-ns-a"}[5m]) / 
(rate(redis_keyspace_hits_total{namespace="redis-ns-a"}[5m]) + 
 rate(redis_keyspace_misses_total{namespace="redis-ns-a"}[5m]))
```

**Network I/O:**
```promql
rate(redis_net_input_bytes_total{namespace="redis-ns-a"}[5m])
rate(redis_net_output_bytes_total{namespace="redis-ns-a"}[5m])
```

## 📈 Key Metrics Reference

### Cluster Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `redis_cluster_state` | Cluster health (1=healthy) | < 1 |
| `redis_cluster_nodes` | Number of cluster nodes | < expected count |
| `redis_cluster_shards` | Number of shards | < expected count |

### Database Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `redis_used_memory_bytes` | Memory usage | > 80% of limit |
| `redis_used_memory_rss_bytes` | Resident set size | > memory limit |
| `redis_connected_clients` | Active connections | > 90% of max |
| `redis_blocked_clients` | Blocked clients | > 0 |
| `redis_evicted_keys_total` | Evicted keys | Increasing trend |
| `redis_expired_keys_total` | Expired keys | - |

### Performance Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `redis_commands_processed_total` | Total commands | - |
| `redis_commands_duration_seconds` | Command latency | > SLA |
| `redis_keyspace_hits_total` | Cache hits | - |
| `redis_keyspace_misses_total` | Cache misses | High ratio |
| `redis_instantaneous_ops_per_sec` | Current ops/sec | - |

### Replication Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `redis_connected_slaves` | Number of replicas | < expected |
| `redis_repl_backlog_size` | Replication backlog | - |
| `redis_master_repl_offset` | Master replication offset | - |

## 🔔 Setting Up Alerts

### Create PrometheusRule

Create a file `prometheus-rules.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-enterprise-alerts
  namespace: redis-ns-a
spec:
  groups:
    - name: redis-enterprise
      interval: 30s
      rules:
        - alert: RedisHighMemoryUsage
          expr: redis_used_memory_bytes / redis_memory_max_bytes > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Redis memory usage is high"
            description: "Redis instance {{ $labels.instance }} is using {{ $value | humanizePercentage }} of available memory"
        
        - alert: RedisDown
          expr: up{job="redis-enterprise-metrics"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Redis instance is down"
            description: "Redis instance {{ $labels.instance }} is not responding"
        
        - alert: RedisHighConnections
          expr: redis_connected_clients / redis_config_maxclients > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Redis connection count is high"
            description: "Redis instance {{ $labels.instance }} has {{ $value | humanizePercentage }} of max connections"
```

Apply the rules:
```bash
oc apply -f prometheus-rules.yaml
```

## 📊 Grafana Dashboards

### Import Redis Enterprise Dashboard

1. Access Grafana (if available in your cluster)
2. Import dashboard from Grafana.com:
   - Dashboard ID: `11835` (Redis Enterprise)
   - Or search for "Redis Enterprise" in Grafana dashboards

### Custom Dashboard

Create custom dashboards with panels for:
- Memory usage over time
- Operations per second
- Latency percentiles (p50, p95, p99)
- Cache hit ratio
- Network throughput
- Replication lag (for Active-Active)

## 🔍 Troubleshooting

### Metrics Not Appearing

```bash
# Check if ServiceMonitor is created
oc get servicemonitor -n redis-ns-a

# Check if Prometheus service exists
oc get svc -n redis-ns-a | grep prom-metrics

# Check user workload monitoring pods
oc get pods -n openshift-user-workload-monitoring

# Check ServiceMonitor targets in Prometheus
# Access Prometheus UI and check Targets page
```

### User Workload Monitoring Not Enabled

```bash
# Verify cluster monitoring config
oc get configmap cluster-monitoring-config -n openshift-monitoring -o yaml

# Should contain: enableUserWorkload: true
```

### Permission Issues

```bash
# Ensure you have monitoring permissions
oc adm policy add-cluster-role-to-user cluster-monitoring-view <username>
```

## 📚 Additional Resources

- [OpenShift Monitoring Documentation](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)
- [Redis Enterprise Metrics](https://redis.io/docs/latest/operate/rs/references/metrics/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

