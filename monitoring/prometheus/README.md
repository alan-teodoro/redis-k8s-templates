# Prometheus Monitoring for Redis Enterprise

This directory contains Prometheus configuration for monitoring Redis Enterprise on Kubernetes.

## Overview

Prometheus monitoring provides:
- ✅ **Cluster metrics** - Node health, memory, CPU, shards
- ✅ **Database metrics** - Operations/sec, memory usage, replication lag
- ✅ **Alerts** - Pre-configured alerts for common issues
- ✅ **ServiceMonitors** - Automatic metric discovery
- ✅ **Recording rules** - Pre-aggregated metrics for performance

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────────┐      ┌─────────────────────────────┐ │
│  │ Redis Enterprise │      │   Prometheus                │ │
│  │                  │      │                             │ │
│  │  ┌────────────┐  │      │  ┌──────────────────────┐  │ │
│  │  │  rec-0     │──┼──────┼─▶│  ServiceMonitor      │  │ │
│  │  │  :8070     │  │      │  │  (discovers targets) │  │ │
│  │  └────────────┘  │      │  └──────────┬───────────┘  │ │
│  │  ┌────────────┐  │      │             │              │ │
│  │  │  rec-1     │──┼──────┼─────────────┘              │ │
│  │  │  :8070     │  │      │             │              │ │
│  │  └────────────┘  │      │  ┌──────────▼───────────┐  │ │
│  │  ┌────────────┐  │      │  │  Prometheus Server   │  │ │
│  │  │  rec-2     │──┼──────┼─▶│  (scrapes & stores)  │  │ │
│  │  │  :8070     │  │      │  │  :9090               │  │ │
│  │  └────────────┘  │      │  └──────────────────────┘  │ │
│  └──────────────────┘      └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
monitoring/prometheus/
├── README.md                          # This file
├── servicemonitors/                   # ServiceMonitor definitions
│   └── redis-enterprise.yaml          # Scrape configuration for REC
├── prometheusrules/                   # Alert rules
│   └── redis-enterprise-alerts.yaml   # Pre-configured alerts
└── recording-rules/                   # Recording rules
    └── redis-enterprise-rules.yaml    # Pre-aggregated metrics
```

---

## Quick Start

### Prerequisites

- Kubernetes cluster with Redis Enterprise deployed
- Prometheus Operator installed (kube-prometheus-stack recommended)
- kubectl access to the cluster

### Step 1: Install Prometheus Operator

Install kube-prometheus-stack using the generic values file:

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack with Redis Enterprise optimized values
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml
```

**Note:** The `values.yaml` file is cloud-agnostic and uses your cluster's default StorageClass.

---

### Step 2: Apply ServiceMonitor

This tells Prometheus where to scrape Redis Enterprise metrics:

```bash
kubectl apply -f servicemonitors/redis-enterprise.yaml
```

**What this does:**
- Discovers the Redis Enterprise prometheus service (`<rec-name>-prom`)
- Scrapes v2 metrics from `https://<IP>:8070/v2` every 15 seconds
- Collects cluster, database, node, and shard metrics
- Also exposes node_exporter v1.8.1 metrics

**Note:** This configuration uses v2 metrics (Redis Enterprise 8.0+). For v1 metrics (7.x), remove the `path: /v2` line.

---

### Step 3: Apply Alert Rules

```bash
kubectl apply -f prometheusrules/redis-enterprise-alerts.yaml
```

**Alerts included:**
- Node down
- High memory usage (>80%, >90%)
- High CPU usage (>80%)
- Cluster not healthy
- License expiring/expired
- Database down
- High replication lag
- Evicting keys

---

### Step 4: Access Grafana

Get Grafana admin password:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
echo ""
```

Port-forward to Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open http://localhost:3000 and login:
- **Username:** `admin`
- **Password:** (from command above)

---

### Step 5: Import Redis Enterprise Dashboard

1. In Grafana, click **"+"** → **"Import"**
2. Click **"Upload JSON file"**
3. Select `../grafana/dashboards/redis-enterprise-overview.json`
4. Select **Prometheus** as data source
5. Click **"Import"**

---

### Step 6: Verify Prometheus Metrics

Port-forward to Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open http://localhost:9090 and check:

1. **Status → Targets** - Should show `redis-enterprise-cluster` targets as UP
2. **Graph** - Query: `node_metrics_up` should return 1 for each node

---

## Available Metrics (v2)

Redis Enterprise v2 metrics (available in 8.0+) provide comprehensive monitoring via the `/v2` endpoint.

### Cluster Metrics

| Metric | Description | Type |
|--------|-------------|------|
| `node_metrics_up` | Node is part of cluster and connected | Gauge |
| `has_quorum` | Cluster has quorum (1=yes, 0=no) | Gauge |
| `license_shards_limit` | Total shard limit by license | Gauge |
| `license_expiration_days` | Days until license expires | Gauge |

### Node Metrics

| Metric | Description | Type |
|--------|-------------|------|
| `node_available_memory_bytes` | Available RAM for database provisioning | Bytes |
| `node_provisional_memory_bytes` | RAM available for new shards | Bytes |
| `node_memory_MemFree_bytes` | Free memory in node | Bytes |
| `node_persistent_storage_avail_bytes` | Available persistent disk space | Bytes |
| `node_ephemeral_storage_avail_bytes` | Available ephemeral disk space | Bytes |
| `node_cert_expires_in_seconds` | Certificate expiration time | Seconds |

### Database (Endpoint) Metrics

| Metric | Description | Type |
|--------|-------------|------|
| `endpoint_read_requests` | Read requests | Counter |
| `endpoint_write_requests` | Write requests | Counter |
| `endpoint_other_requests` | Other requests | Counter |
| `endpoint_ingress` | Ingress bytes | Counter |
| `endpoint_egress` | Egress bytes | Counter |
| `endpoint_read_requests_latency_histogram` | Read latency histogram | Histogram |
| `endpoint_write_requests_latency_histogram` | Write latency histogram | Histogram |
| `endpoint_connections_rate` | Connection rate | Gauge |

### Shard (Redis Server) Metrics

| Metric | Description | Type |
|--------|-------------|------|
| `redis_server_up` | Shard is up and running | Gauge |
| `redis_server_used_memory` | Memory used by shard | Bytes |
| `redis_server_db_keys` | Total keys in shard | Gauge |
| `redis_server_connected_clients` | Client connections | Gauge |
| `redis_server_total_commands_processed` | Commands processed | Counter |
| `redis_server_keyspace_read_hits` | Read hits | Counter |
| `redis_server_keyspace_read_misses` | Read misses | Counter |
| `redis_server_evicted_keys` | Evicted keys | Counter |
| `redis_server_expired_keys` | Expired keys | Counter |

**Full list:** See [Prometheus Metrics v2 Documentation](https://redis.io/docs/latest/operate/rs/references/metrics/prometheus-metrics-v2/)

---

## Example Queries (v2)

### Cluster Health

```promql
# Nodes up and reporting
count(node_metrics_up == 1)

# Cluster has quorum
has_quorum

# Node memory usage percentage
((node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes) / node_memory_MemTotal_bytes) * 100

# Node CPU usage (user + system)
rate(node_cpu_seconds_total{mode="user"}[5m]) * 100 + rate(node_cpu_seconds_total{mode="system"}[5m]) * 100

# Disk space available
node_filesystem_avail_bytes / node_filesystem_size_bytes * 100
```

### Database Metrics

```promql
# Total operations per second (read + write + other)
rate(endpoint_read_requests[5m]) + rate(endpoint_write_requests[5m]) + rate(endpoint_other_requests[5m])

# Read operations per second
rate(endpoint_read_requests[5m])

# Write operations per second
rate(endpoint_write_requests[5m])

# Read latency p99.9
histogram_quantile(0.999, sum(rate(endpoint_read_requests_latency_histogram_bucket[5m])) by (le, db))

# Write latency p99.9
histogram_quantile(0.999, sum(rate(endpoint_write_requests_latency_histogram_bucket[5m])) by (le, db))

# Connection rate
endpoint_connections_rate
```

### Shard Metrics

```promql
# Total keys across all shards
sum(redis_server_db_keys)

# Commands per second per shard
rate(redis_server_total_commands_processed[5m])

# Memory usage per shard
redis_server_used_memory

# Cache hit rate
rate(redis_server_keyspace_read_hits[5m]) / (rate(redis_server_keyspace_read_hits[5m]) + rate(redis_server_keyspace_read_misses[5m]))
```

---

## Next Steps

- [Configure Grafana dashboards](../grafana/)
- [View available alert rules](./prometheusrules/)
- [Customize ServiceMonitors](./servicemonitors/)

---

## Troubleshooting

### No metrics appearing

1. Check ServiceMonitor was created:
   ```bash
   kubectl get servicemonitor -n monitoring
   ```

2. Check Prometheus targets:
   - Port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`
   - Open: http://localhost:9090/targets
   - Look for `redis-enterprise-cluster`

3. Check ServiceMonitor labels:
   ```bash
   kubectl get servicemonitor -n monitoring redis-enterprise-cluster -o yaml | grep -A 5 labels
   ```
   Must have `release: kube-prometheus-stack` label.

### Alerts not firing

1. Check PrometheusRule was loaded:
   ```bash
   kubectl get prometheusrule -n monitoring
   ```

2. Check Prometheus rules:
   - Open: http://localhost:9090/rules
   - Verify rules are loaded

3. Check PrometheusRule labels match Prometheus selector

### Metrics v1 vs v2

**How to verify which version is being used:**

1. Check the scrape endpoint in Prometheus targets:
   - Open: http://localhost:9090/targets
   - Look for the endpoint URL:
     - v1: `https://<IP>:8070/metrics` or `https://<IP>:8070/`
     - v2: `https://<IP>:8070/v2`

2. Test metrics in Prometheus:
   ```promql
   # v1 metric
   node_up

   # v2 metric
   node_metrics_up
   ```

**To switch between v1 and v2:**

- **For v2** (Redis Enterprise 8.0+): Add `path: /v2` to ServiceMonitor endpoints
- **For v1** (Redis Enterprise 7.x): Remove the `path` field (defaults to `/`)

**Note:** After changing the ServiceMonitor, restart Prometheus pod to reload configuration:
```bash
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
```

---

## Additional Resources

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Redis Enterprise Metrics](https://docs.redis.com/latest/rs/clusters/monitoring/prometheus-metrics-definitions/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

