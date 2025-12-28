# Redis Enterprise Log Collector

The **Log Collector** is an official Redis Enterprise tool that collects logs and diagnostic information from your Kubernetes environment to facilitate troubleshooting with Redis support.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Operation Modes](#operation-modes)
- [Usage Guide](#usage-guide)
- [Available Options](#available-options)
- [Required RBAC](#required-rbac)
- [Troubleshooting](#troubleshooting)
- [What is Collected](#what-is-collected)

---

## 🎯 Overview

### What is the Log Collector?

The **log_collector.py** is an official Redis Enterprise Python script that:

- ✅ Collects logs from all Redis Enterprise components (Operator, REC, REDB)
- ✅ Collects Kubernetes resource information (pods, services, configmaps, etc.)
- ✅ Packages everything into a `.tar.gz` file for sending to support
- ✅ Supports collection from multiple namespaces
- ✅ Can collect Istio information (if used)

### When to Use?

Use the log collector when:

- 🔴 Having problems with Redis Enterprise Operator
- 🔴 Databases are not working correctly
- 🔴 Need to open a ticket with Redis support
- 🔴 Want to perform detailed analysis of production issues

---

## ✅ Prerequisites

### 1. Python 3.6+

```bash
python3 --version
# Python 3.6 or higher
```

### 2. PyYAML Module

```bash
pip3 install pyyaml
```

### 3. kubectl or oc CLI

```bash
kubectl version --client
# or
oc version --client
```

### 4. RBAC Permissions

The user running the script needs adequate RBAC permissions. See [Required RBAC](#required-rbac).

---

## 🔧 Operation Modes

The log collector has **2 modes**:

### 1. `restricted` Mode (Default - Recommended)

Collects **only** resources created by the Operator and Redis Enterprise:

- ✅ Pods with label `app=redis-enterprise`
- ✅ Resources managed by the Operator
- ✅ Operator and REC/REDB logs
- ✅ **Faster and focused**

```bash
python3 log_collector.py --mode restricted
```

### 2. `all` Mode (Complete)

Collects **all** resources from the namespace:

- ✅ All pods in the namespace
- ✅ All resources (services, configmaps, secrets, etc.)
- ✅ **Slower, but more complete**

```bash
python3 log_collector.py --mode all
```

---

## 📖 Usage Guide

### Basic Usage

```bash
# 1. Download the script
curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py

# 2. Run (uses current context namespace)
python3 log_collector.py

# 3. Result
# File: redis_enterprise_k8s_debug_info_<timestamp>.tar.gz
```

### Specify Namespace

```bash
# Single namespace
python3 log_collector.py -n redis-enterprise

# Multiple namespaces
python3 log_collector.py -n redis-enterprise,redis-prod,redis-dev
```

### Specify Output Directory

```bash
python3 log_collector.py -o /tmp/redis-logs
```

### Collect from All Pods

```bash
python3 log_collector.py -a
# or
python3 log_collector.py --logs_from_all_pods
```

### Collect Istio Information

```bash
python3 log_collector.py --collect_istio
```

### Collect by Helm Release

```bash
python3 log_collector.py --helm_release_name redis-enterprise
```

---

## ⚙️ Available Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n, --namespace` | Namespace(s) to collect from (comma-separated) | Current context |
| `-o, --output_dir` | Output directory for tar.gz file | Current directory |
| `-a, --logs_from_all_pods` | Collect logs from all pods (not just Redis Enterprise) | `false` |
| `-t, --timeout` | Timeout for kubectl commands (seconds, 0=no timeout) | `180` |
| `--mode` | Collection mode: `restricted` or `all` | `restricted` |
| `--collect_istio` | Collect Istio information | `false` |
| `--helm_release_name` | Helm release name | - |
| `--k8s_cli` | Kubernetes CLI to use (`kubectl` or `oc`) | Auto-detect |
| `--collect_rbac_resources` | Collect RBAC resources (dev flag) | `false` |
| `-h, --help` | Show help | - |

---

## 🔐 Required RBAC

### For `restricted` Mode (Minimum)

See file `01-rbac-restricted.yaml` for complete configuration.

**Required permissions:**
- `get`, `list` on pods, services, configmaps, secrets
- `get`, `list` on CRDs (REC, REDB, RERC, REAADB)
- `get` logs from pods

### For `all` Mode (Complete)

See file `02-rbac-all.yaml` for complete configuration.

**Additional permissions:**
- `get`, `list` on **all** namespace resources
- `get`, `list` on nodes (cluster-scoped)

---

## 🔍 Troubleshooting

### Error: `ModuleNotFoundError: No module named 'yaml'`

**Solution:**
```bash
pip3 install pyyaml
```

### Error: `Permission denied`

**Cause:** Insufficient RBAC

**Solution:**
```bash
# Check permissions
kubectl auth can-i get pods -n redis-enterprise
kubectl auth can-i get logs -n redis-enterprise

# Apply adequate RBAC
kubectl apply -f 01-rbac-restricted.yaml
```

### Timeout in Commands

**Solution:**
```bash
# Increase timeout (default: 180s)
python3 log_collector.py -t 300

# Disable timeout
python3 log_collector.py -t 0
```

### Script Cannot Find kubectl/oc

**Solution:**
```bash
# Specify full path
python3 log_collector.py --k8s_cli /usr/local/bin/kubectl
```

---

## 📦 What is Collected?

### Logs
- Operator logs
- REC pod logs
- REDB pod logs
- Services pod logs

### Kubernetes Resources
- Pods (describe + logs)
- Services
- ConfigMaps
- Secrets (metadata only, not values)
- PersistentVolumeClaims
- Events

### Custom Resources
- RedisEnterpriseCluster (REC)
- RedisEnterpriseDatabase (REDB)
- RedisEnterpriseRemoteCluster (RERC)
- RedisEnterpriseActiveActiveDatabase (REAADB)

### Cluster Information
- Nodes
- StorageClasses
- Namespaces

### Output Structure

```
redis_enterprise_k8s_debug_info_<timestamp>/
├── cluster_info/
│   ├── nodes.yaml
│   ├── storageclasses.yaml
│   └── namespaces.yaml
├── pods/
│   ├── redis-enterprise-operator-xxx/
│   │   ├── describe.yaml
│   │   └── logs.txt
│   └── rec-0/
│       ├── describe.yaml
│       └── logs.txt
├── services/
├── configmaps/
├── secrets/
├── custom_resources/
│   ├── redisenterpriseclusters.yaml
│   └── redisenterprisedatabases.yaml
└── events.yaml
```

---

## 🔗 References

- [Official Documentation - Collect Logs](https://redis.io/docs/latest/operate/kubernetes/logs/collect-logs/)
- [Redis Enterprise K8s Docs](https://github.com/RedisLabs/redis-enterprise-k8s-docs)
- [Log Collector Script](https://github.com/RedisLabs/redis-enterprise-k8s-docs/tree/master/log_collector)

