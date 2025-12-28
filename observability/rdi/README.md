# RDI Observability

Observability strategy for RDI (Redis Data Integration) on Kubernetes.

---

## 📊 Overview

RDI provides comprehensive observability through:
- **Prometheus Metrics** - Two separate endpoints for collector and processor
- **Grafana Dashboards** - Pre-built dashboards for monitoring
- **Logs** - Structured logging via fluentd
- **Alerts** - Critical alerts for failures only

---

## 🎯 Observability Strategy

### Philosophy: Alert on Failures, Not Performance

**DO Alert:**
- ✅ Collector disconnected from source database
- ✅ Processing errors (rejected records)
- ✅ Snapshot failures

**DON'T Alert:**
- ❌ Lag increasing (unless critical threshold)
- ❌ CPU/memory usage (unless pod is OOMKilled)
- ❌ Throughput decreasing (unless zero)

**Rationale**: RDI is designed to handle variable load. Temporary lag or performance degradation is normal and self-correcting.

---

## 📈 Metrics Endpoints

RDI exposes **two separate metrics endpoints**:

### 1. Collector Metrics (Source Database)

**Endpoint**: `http://rdi-metric-exporter:8081/metrics/collector-source`

**Key Metrics:**

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `Connected` | Gauge | Connection status (0=disconnected, 1=connected) | `== 0` |
| `MilliSecondsBehindSource` | Gauge | Lag in milliseconds | `> 60000` (1 min) |
| `NumberOfEvents` | Counter | Total events captured | - |
| `NumberOfErroneousEvents` | Counter | Events with errors | `> 0` |
| `SnapshotCompleted` | Gauge | Snapshot status (0=running, 1=completed) | - |
| `SnapshotAborted` | Gauge | Snapshot aborted (0=ok, 1=aborted) | `== 1` |

### 2. Stream Processor Metrics (Redis Target)

**Endpoint**: `http://rdi-metric-exporter:8081/metrics/rdi`

**Key Metrics:**

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `rdi_processed_records_total` | Counter | Total records processed | - |
| `rdi_rejected_records_total` | Counter | Records rejected due to errors | `> 0` |
| `rdi_lag_ms` | Gauge | Processing lag in milliseconds | `> 60000` (1 min) |
| `rdi_throughput_records_per_sec` | Gauge | Current throughput | - |

---

## 🚨 Critical Alerts (3 Only)

### Alert 1: Collector Disconnected

**Severity**: CRITICAL  
**Condition**: `Connected == 0`  
**Impact**: No data is being captured from source database  
**Action**: Check source database connectivity and credentials

```yaml
# Prometheus alert rule
- alert: RDICollectorDisconnected
  expr: Connected{job="rdi-collector"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "RDI collector disconnected from source database"
    description: "RDI collector has been disconnected for more than 2 minutes"
```

### Alert 2: Processing Errors

**Severity**: WARNING  
**Condition**: `NumberOfErroneousEvents > 0` OR `rdi_rejected_records_total > 0`  
**Impact**: Some data is not being replicated correctly  
**Action**: Check processor logs for transformation errors

```yaml
# Prometheus alert rule
- alert: RDIProcessingErrors
  expr: |
    (rate(NumberOfErroneousEvents{job="rdi-collector"}[5m]) > 0) OR
    (rate(rdi_rejected_records_total{job="rdi-processor"}[5m]) > 0)
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "RDI processing errors detected"
    description: "RDI is rejecting records due to processing errors"
```

### Alert 3: Snapshot Aborted

**Severity**: CRITICAL  
**Condition**: `SnapshotAborted == 1`  
**Impact**: Initial data load failed  
**Action**: Check collector logs and restart pipeline

```yaml
# Prometheus alert rule
- alert: RDISnapshotAborted
  expr: SnapshotAborted{job="rdi-collector"} == 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "RDI snapshot aborted"
    description: "RDI initial snapshot has been aborted"
```

---

## 📊 Grafana Dashboards

### Dashboard 1: RDI Overview

**Panels:**
- Connection status (collector)
- Lag (milliseconds behind source)
- Throughput (records/sec)
- Total events captured
- Total events processed
- Error rate

### Dashboard 2: RDI Performance

**Panels:**
- CPU usage (collector, processor)
- Memory usage (collector, processor)
- Network I/O
- Disk I/O (RDI database)

### Dashboard 3: RDI Errors

**Panels:**
- Erroneous events (collector)
- Rejected records (processor)
- Error logs (last 100 lines)

---

## 🔍 Querying Metrics

### Via Prometheus

```promql
# Check connection status
Connected{job="rdi-collector"}

# Check lag
MilliSecondsBehindSource{job="rdi-collector"}

# Check throughput
rate(rdi_processed_records_total{job="rdi-processor"}[1m])

# Check error rate
rate(rdi_rejected_records_total{job="rdi-processor"}[5m])
```

### Via kubectl port-forward

```bash
# Port forward to metrics exporter
kubectl port-forward -n rdi svc/rdi-metric-exporter 8081:8081

# Query collector metrics
curl http://localhost:8081/metrics/collector-source

# Query processor metrics
curl http://localhost:8081/metrics/rdi
```

---

## 🔗 Useful Links

- [RDI Observability](https://redis.io/docs/latest/integrate/redis-data-integration/observability/)
- [RDI Metrics](https://redis.io/docs/latest/integrate/redis-data-integration/observability/prometheus/)
- [RDI Logging](https://redis.io/docs/latest/integrate/redis-data-integration/observability/logging/)

