# Log Collector Usage Examples

This document contains practical examples of using the log collector in different scenarios.

---

## 📋 Table of Contents

- [Basic Scenarios](#basic-scenarios)
- [Advanced Scenarios](#advanced-scenarios)
- [Production Scenarios](#production-scenarios)
- [Specific Troubleshooting](#specific-troubleshooting)

---

## 🎯 Basic Scenarios

### 1. Simple Collection (Current Namespace)

```bash
# Download the script
curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py

# Run (uses current kubectl context namespace)
python3 log_collector.py

# Result
# File: redis_enterprise_k8s_debug_info_<timestamp>.tar.gz
```

### 2. Collection from Specific Namespace

```bash
# Collect from redis-enterprise namespace
python3 log_collector.py -n redis-enterprise

# Collect from multiple namespaces
python3 log_collector.py -n redis-enterprise,redis-prod,redis-dev
```

### 3. Collection with Custom Output

```bash
# Specify output directory
python3 log_collector.py -n redis-enterprise -o /tmp/redis-logs

# Check generated file
ls -lh /tmp/redis-logs/redis_enterprise_k8s_debug_info_*.tar.gz
```

---

## 🔧 Advanced Scenarios

### 4. Complete Collection (All Mode)

```bash
# Collect ALL resources from namespace
python3 log_collector.py -n redis-enterprise --mode all

# ⚠️ Slower, but more complete
# Useful when the problem is not clear
```

### 5. Collection with Istio

```bash
# Collect Istio information
python3 log_collector.py -n redis-enterprise --collect_istio

# Includes:
# - Istio sidecar logs
# - Envoy configuration
# - Virtual services
# - Destination rules
```

### 6. Collection by Helm Release

```bash
# Collect by Helm release name
python3 log_collector.py --helm_release_name redis-enterprise

# Automatically detects namespace from Helm release
```

### 7. Collection with Extended Timeout

```bash
# Increase timeout for large clusters
python3 log_collector.py -n redis-enterprise -t 600

# Disable timeout (wait indefinitely)
python3 log_collector.py -n redis-enterprise -t 0
```

---

## 🏭 Production Scenarios

### 8. Multi-Namespace Production Environment

```bash
# Collect from all production namespaces
python3 log_collector.py \
  -n redis-prod-us,redis-prod-eu,redis-prod-asia \
  -o /var/log/redis-support \
  -t 300

# Result: Single tar.gz with all namespaces
```

### 9. Complete Diagnostic for Support Ticket

```bash
# Complete collection for support
python3 log_collector.py \
  -n redis-enterprise \
  --mode all \
  -a \
  --collect_istio \
  -o /tmp/redis-support-ticket-12345

# Upload to Redis support:
# File: /tmp/redis-support-ticket-12345/redis_enterprise_k8s_debug_info_*.tar.gz
```

### 10. Scheduled Collection (Cron)

```bash
# Add to crontab for daily collection
# Run every day at 2 AM
0 2 * * * /usr/bin/python3 /opt/scripts/log_collector.py -n redis-enterprise -o /var/log/redis-daily

# Keep last 7 days
0 3 * * * find /var/log/redis-daily -name "*.tar.gz" -mtime +7 -delete
```

---

## 🔍 Specific Troubleshooting

### 11. Operator Not Starting

```bash
# Collect operator logs
python3 log_collector.py -n redis-enterprise

# Extract and check operator logs
cd /tmp/operator-issue
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
cat */pods/redis-enterprise-operator-*/logs.txt
```

### 12. Specific Database Issue

```bash
# Collect logs from specific namespace
python3 log_collector.py -n redis-enterprise

# Extract and search for specific database
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
grep -r "redis-db-prod" */
```

### 13. Performance Issue

```bash
# Collect with all mode for complete analysis
python3 log_collector.py \
  -n redis-enterprise \
  --mode all \
  -a \
  -t 600

# Analyze resource usage in extracted files
```

### 14. Network Connectivity Issue

```bash
# Collect with Istio information
python3 log_collector.py \
  -n redis-enterprise \
  --collect_istio

# Check network policies and services
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
cat */services/*.yaml
cat */networkpolicies/*.yaml
```

### 15. Upgrade Failure

```bash
# Collect before and after upgrade
# Before:
python3 log_collector.py -n redis-enterprise -o /tmp/before-upgrade

# After upgrade (if failed):
python3 log_collector.py -n redis-enterprise -o /tmp/after-upgrade

# Compare both files
```

---

## 📊 Analyzing Collected Data

### Extract and Navigate

```bash
# Extract tar.gz
tar -xzf redis_enterprise_k8s_debug_info_20231215_143022.tar.gz

# Navigate to directory
cd redis_enterprise_k8s_debug_info_20231215_143022/

# Directory structure:
# cluster_info/    - Cluster-level information
# pods/            - Pod describes and logs
# services/        - Services
# configmaps/      - ConfigMaps
# secrets/         - Secrets (metadata only)
# custom_resources/- REC, REDB, RERC, REAADB
# events.yaml      - Kubernetes events
```

### Useful Analysis Commands

```bash
# Search for errors in logs
grep -r "ERROR\|FATAL\|CRITICAL" */

# Search for warnings
grep -r "WARN" */

# Check events
cat */events.yaml | grep -A 5 "Warning"

# Check REC status
cat */custom_resources/redisenterpriseclusters.yaml | grep -A 20 "status:"

# Check REDB status
cat */custom_resources/redisenterprisedatabases.yaml | grep -A 20 "status:"
```

---

## 🔗 References

- [Official Documentation - Collect Logs](https://redis.io/docs/latest/operate/kubernetes/logs/collect-logs/)
- [Redis Enterprise K8s Docs](https://github.com/RedisLabs/redis-enterprise-k8s-docs)

