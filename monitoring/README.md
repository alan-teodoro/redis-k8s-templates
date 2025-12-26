# Monitoring for Redis Enterprise

Comprehensive monitoring solution for Redis Enterprise on Kubernetes using Prometheus and Grafana.

**Platform-agnostic:** Works on EKS, GKE, AKS, OpenShift, and vanilla Kubernetes.

## 📋 Overview

This monitoring stack provides:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **ServiceMonitor** - Automatic metrics scraping
- **PrometheusRules** - Pre-configured alerts
- **Dashboards** - Redis Enterprise overview

### Metrics Version

Uses **Prometheus Metrics v2** (Redis Enterprise 8.0+):
- Endpoint: `https://<rec-name>-prom:8070/v2`
- Includes cluster, database, node, and shard metrics
- Also exposes node_exporter v1.8.1 metrics

## 📁 Structure

```
monitoring/
├── README.md                                  # This file
├── prometheus/
│   ├── README.md                              # Prometheus setup guide
│   ├── values.yaml                            # Helm values for kube-prometheus-stack
│   ├── servicemonitors/
│   │   └── redis-enterprise.yaml              # ServiceMonitor for metrics scraping
│   └── prometheusrules/
│       └── redis-enterprise-alerts.yaml       # Alert rules
└── grafana/
    ├── README.md                              # Grafana setup guide
    ├── dashboards/
    │   └── redis-enterprise-overview.json     # Main dashboard
    └── datasources/
```

## 🚀 Quick Start

### Step 1: Install kube-prometheus-stack

```bash
cd prometheus/

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with custom values
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f values.yaml
```

### Step 2: Deploy ServiceMonitor

```bash
kubectl apply -f servicemonitors/redis-enterprise.yaml
```

### Step 3: Deploy Alert Rules

```bash
kubectl apply -f prometheusrules/redis-enterprise-alerts.yaml
```

### Step 4: Access Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000
# User: admin
# Password: prom-operator
```

### Step 5: Import Dashboard

1. In Grafana: **"+"** → **"Import"**
2. Upload `grafana/dashboards/redis-enterprise-overview.json`
3. Select **Prometheus** data source
4. Click **"Import"**

## 📊 What Gets Monitored

### Cluster Metrics
- Node status (up/down)
- Cluster quorum
- Memory usage
- CPU usage
- Disk usage

### Database Metrics
- Operations/sec
- Memory usage
- Connections
- Hit rate
- Evicted keys
- Replication lag (Active-Active)

### Shard Metrics
- CPU usage per shard
- Memory per shard
- Commands/sec per shard

## 🚨 Pre-configured Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| **RedisEnterpriseNodeDown** | Critical | Node down for 2+ minutes |
| **RedisEnterpriseClusterLostQuorum** | Critical | Cluster lost quorum |
| **RedisEnterpriseHighMemoryUsage** | Warning | Memory usage > 80% for 5+ minutes |
| **RedisEnterpriseDatabaseDown** | Critical | Database unavailable for 2+ minutes |
| **RedisEnterpriseDatabaseHighMemory** | Warning | Database memory > 90% |
| **RedisEnterpriseHighEvictionRate** | Warning | High eviction rate |
| **RedisEnterpriseReplicationLag** | Warning | Replication lag > 10s (Active-Active) |

## 🔐 Access

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

### Alertmanager

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open: http://localhost:9093
```

## 🔧 Configuration

### Customize Alerts

Edit `prometheus/prometheusrules/redis-enterprise-alerts.yaml`:

```yaml
- alert: RedisEnterpriseHighMemoryUsage
  expr: |
    ((node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes) * 100 > 80
  for: 5m
  labels:
    severity: warning
```

### Adjust Scrape Interval

Edit `prometheus/servicemonitors/redis-enterprise.yaml`:

```yaml
endpoints:
  - port: prometheus
    path: /v2
    interval: 15s  # Change to 30s, 60s, etc.
```

### Add Alertmanager Receivers

Edit `prometheus/values.yaml`:

```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'YOUR_SLACK_WEBHOOK_URL'
            channel: '#redis-alerts'
```

## 📚 Additional Resources

- [Prometheus Setup Guide](prometheus/README.md)
- [Grafana Setup Guide](grafana/README.md)
- [Redis Enterprise Metrics v2](https://redis.io/docs/latest/operate/rs/references/metrics/prometheus-metrics-v2/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

