# Grafana Dashboards for Redis Enterprise

This directory contains pre-built Grafana dashboards for visualizing Redis Enterprise metrics.

## Overview

These dashboards provide comprehensive visualization of:
- ✅ **Cluster health** - Node status, memory, CPU, shards
- ✅ **Database metrics** - Operations/sec, latency, memory usage
- ✅ **Replication** - Lag, sync status
- ✅ **Performance** - Throughput, hit rate, evictions

---

## Available Dashboards

### 1. Redis Enterprise Overview
**File:** `dashboards/redis-enterprise-overview.json`

**Panels:**
- Cluster Nodes Up
- Databases Active
- Node Memory Usage %
- Node CPU Usage %
- Total Operations/sec
- Cluster Shards

**Use case:** High-level cluster health monitoring

---

### 2. Redis Enterprise Cluster (Coming Soon)
**File:** `dashboards/redis-enterprise-cluster.json`

**Panels:**
- Node details (memory, CPU, disk)
- Shard distribution
- License information
- Network traffic
- Cluster events

**Use case:** Detailed cluster analysis

---

### 3. Redis Enterprise Databases (Coming Soon)
**File:** `dashboards/redis-enterprise-databases.json`

**Panels:**
- Database list with status
- Memory usage per database
- Operations/sec per database
- Replication lag
- Hit rate
- Evictions

**Use case:** Database-level monitoring and troubleshooting

---

## Installation

### Prerequisites

- Grafana installed (via kube-prometheus-stack or standalone)
- Prometheus data source configured
- Redis Enterprise metrics being scraped

### Import Dashboards

#### Method 1: Via Grafana UI

1. Login to Grafana
2. Click **"+"** (left sidebar) → **"Import"**
3. Click **"Upload JSON file"**
4. Select dashboard file from `dashboards/` directory
5. Select **Prometheus** as data source
6. Click **"Import"**

#### Method 2: Via ConfigMap (Automated)

Create ConfigMap with dashboard:

```bash
kubectl create configmap grafana-dashboard-redis-overview \
  --from-file=redis-enterprise-overview.json=dashboards/redis-enterprise-overview.json \
  -n monitoring
```

Label it for Grafana sidecar to pick up:

```bash
kubectl label configmap grafana-dashboard-redis-overview \
  grafana_dashboard=1 \
  -n monitoring
```

Grafana will automatically load the dashboard.

#### Method 3: Via Helm Values

If using kube-prometheus-stack, add to `values.yaml`:

```yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'redis-enterprise'
          orgId: 1
          folder: 'Redis Enterprise'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/redis-enterprise
  
  dashboards:
    redis-enterprise:
      redis-enterprise-overview:
        file: dashboards/redis-enterprise-overview.json
```

---

## Customization

### Modify Refresh Rate

Edit dashboard JSON:

```json
{
  "refresh": "30s",  // Change to "10s", "1m", "5m", etc.
  ...
}
```

### Add Custom Panels

1. Open dashboard in Grafana
2. Click **"Add panel"**
3. Configure query and visualization
4. Click **"Apply"**
5. Save dashboard
6. Export JSON: **Dashboard settings** → **JSON Model** → Copy

### Change Time Range

Edit dashboard JSON:

```json
{
  "time": {
    "from": "now-6h",  // Change to "now-1h", "now-24h", etc.
    "to": "now"
  },
  ...
}
```

---

## Dashboard Variables

Dashboards support variables for filtering:

- **`$cluster`** - Filter by cluster name
- **`$namespace`** - Filter by namespace
- **`$database`** - Filter by database name
- **`$node`** - Filter by node/pod

To use variables in queries:

```promql
redis_db_used_memory{cluster="$cluster", database="$database"}
```

---

## Useful Queries

### Cluster Metrics

```promql
# Nodes up
count(up{job="redis-enterprise-cluster"} == 1)

# Total memory used
sum(redis_node_memory_used_bytes)

# Total operations/sec
sum(rate(redis_db_total_req[5m]))
```

### Database Metrics

```promql
# Database memory usage %
(redis_db_used_memory / redis_db_memory_limit) * 100

# Operations per second
rate(redis_db_total_req[5m])

# Hit rate %
(rate(redis_db_keyspace_hits[5m]) / (rate(redis_db_keyspace_hits[5m]) + rate(redis_db_keyspace_misses[5m]))) * 100
```

---

## Troubleshooting

### Dashboard shows "No data"

1. **Check Prometheus data source:**
   - Go to **Configuration** → **Data Sources**
   - Test Prometheus connection

2. **Verify metrics exist:**
   - Go to Prometheus UI: http://localhost:9090
   - Query: `up{job="redis-enterprise-cluster"}`
   - Should return results

3. **Check time range:**
   - Ensure dashboard time range includes data
   - Try "Last 1 hour" or "Last 6 hours"

### Panels show errors

1. **Check PromQL syntax:**
   - Click panel title → **Edit**
   - Check query for errors

2. **Verify metric names:**
   - Metric names may vary by Redis Enterprise version
   - Check available metrics in Prometheus

---

## Next Steps

- [Configure alerts in Prometheus](../prometheus/prometheusrules/)
- [Set up AlertManager notifications](../prometheus/alertmanager/)
- [Platform-specific monitoring guides](../../platforms/)

---

## Additional Resources

- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)
- [Redis Enterprise Metrics](https://docs.redis.com/latest/rs/clusters/monitoring/prometheus-metrics-definitions/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

