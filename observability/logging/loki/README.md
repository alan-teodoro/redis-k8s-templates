# Grafana Loki for Redis Enterprise Logging

Lightweight, Kubernetes-native logging solution using Grafana Loki and Promtail.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [Querying Logs](#querying-logs)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Grafana Loki** is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

**Benefits:**
- ✅ Lightweight (indexes labels, not full text)
- ✅ Native Grafana integration
- ✅ Cost-effective storage
- ✅ Kubernetes-native
- ✅ Easy to operate

**Components:**
- **Loki**: Log aggregation and storage
- **Promtail**: Log collector (DaemonSet)
- **Grafana**: Visualization and querying

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Loki Architecture                         │
│                                                              │
│  ┌──────────────┐                                           │
│  │ Redis Pods   │                                           │
│  │ (logs to     │                                           │
│  │  stdout)     │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐ │
│  │  Promtail    │ ───▶ │     Loki     │ ───▶ │  Storage  │ │
│  │ (DaemonSet)  │      │  (StatefulSet│      │ (PVC/S3)  │ │
│  │              │      │   or Deploy) │      │           │ │
│  └──────────────┘      └──────────────┘      └───────────┘ │
│                                │                            │
│                                ▼                            │
│                        ┌──────────────┐                     │
│                        │   Grafana    │                     │
│                        │ (Query & UI) │                     │
│                        └──────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Prerequisites

1. **Kubernetes cluster** with kubectl access
2. **Helm 3** installed
3. **Grafana** (optional, for visualization)
4. **Storage class** for persistent volumes

---

## 📦 Installation

### Step 1: Add Grafana Helm Repository

See: [01-install-loki.yaml](01-install-loki.yaml)

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace logging
```

### Step 2: Install Loki Stack

```bash
# Install Loki stack (Loki + Promtail + Grafana)
helm install loki grafana/loki-stack \
  --namespace logging \
  --set grafana.enabled=true \
  --set prometheus.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

Or use custom values file:

```bash
kubectl apply -f 01-install-loki.yaml
```

### Step 3: Configure Promtail

See: [02-promtail-config.yaml](02-promtail-config.yaml)

```bash
kubectl apply -f 02-promtail-config.yaml
```

### Step 4: Configure Grafana Data Source

See: [03-grafana-datasource.yaml](03-grafana-datasource.yaml)

```bash
kubectl apply -f 03-grafana-datasource.yaml
```

---

## 🔍 Verification

### Check Loki Pods

```bash
# Check Loki pods
kubectl get pods -n logging -l app=loki

# Check Promtail pods (should be on every node)
kubectl get pods -n logging -l app=promtail

# Check Grafana pod
kubectl get pods -n logging -l app.kubernetes.io/name=grafana
```

### Access Grafana

```bash
# Get Grafana admin password
kubectl get secret -n logging loki-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port-forward to Grafana
kubectl port-forward -n logging svc/loki-grafana 3000:80

# Open browser: http://localhost:3000
# Username: admin
# Password: (from above command)
```

### Test Log Collection

```bash
# Generate test logs
kubectl run test-logger --image=busybox --restart=Never -n redis-enterprise -- \
  sh -c 'while true; do echo "Test log message"; sleep 5; done'

# Wait a few seconds, then check in Grafana
# Navigate to Explore → Select Loki data source
# Query: {namespace="redis-enterprise", pod="test-logger"}
```

---

## 🔎 Querying Logs

### LogQL Basics

LogQL is Loki's query language, similar to PromQL.

**Basic Query:**
```
{namespace="redis-enterprise"}
```

**Filter by Pod:**
```
{namespace="redis-enterprise", pod="rec-0"}
```

**Filter by Container:**
```
{namespace="redis-enterprise", container="redis-enterprise"}
```

**Search for Text:**
```
{namespace="redis-enterprise"} |= "ERROR"
```

**Regex Search:**
```
{namespace="redis-enterprise"} |~ "error|ERROR|Error"
```

**Exclude Text:**
```
{namespace="redis-enterprise"} != "DEBUG"
```

### Common Queries for Redis Enterprise

**All Redis Enterprise Logs:**
```
{namespace="redis-enterprise"}
```

**Errors Only:**
```
{namespace="redis-enterprise"} |= "ERROR"
```

**Database Operations:**
```
{namespace="redis-enterprise"} |= "database" |= "created"
```

**Authentication Events:**
```
{namespace="redis-enterprise"} |= "authentication"
```

**Cluster Events:**
```
{namespace="redis-enterprise"} |= "cluster" |= "node"
```

---

## 🔧 Troubleshooting

### Issue: No logs appearing in Grafana

**Solution:**
```bash
# Check Promtail is running
kubectl get pods -n logging -l app=promtail

# Check Promtail logs
kubectl logs -n logging -l app=promtail --tail=50

# Check Loki is running
kubectl get pods -n logging -l app=loki

# Check Loki logs
kubectl logs -n logging -l app=loki --tail=50
```

### Issue: Promtail not collecting logs

**Solution:**
```bash
# Verify Promtail has access to /var/log/pods
kubectl exec -it -n logging <promtail-pod> -- ls -la /var/log/pods

# Check Promtail configuration
kubectl get configmap -n logging promtail -o yaml
```

### Issue: Loki storage full

**Solution:**
```bash
# Check PVC usage
kubectl get pvc -n logging

# Increase PVC size (if storage class supports it)
kubectl patch pvc loki -n logging -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Or configure retention period in Loki config
```

---

## 📚 Related Documentation

- [Monitoring](../../monitoring/README.md)
- [Alerting](../../alerting/README.md)
- [Grafana Dashboards](../../monitoring/grafana/README.md)

---

## 🔗 References

- Grafana Loki: https://grafana.com/oss/loki/
- LogQL: https://grafana.com/docs/loki/latest/logql/
- Promtail: https://grafana.com/docs/loki/latest/clients/promtail/

