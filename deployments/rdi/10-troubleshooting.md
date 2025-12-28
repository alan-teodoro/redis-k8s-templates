# RDI Troubleshooting Guide

Complete troubleshooting guide for RDI (Redis Data Integration) on Kubernetes.

---

## 🔍 Quick Diagnosis

### Check Overall Status

```bash
# Check all RDI pods
kubectl get pods -n rdi

# Expected pods:
# - collector-api-xxx         (1/1 Running)
# - rdi-api-xxx               (1/1 Running)
# - rdi-metric-exporter-xxx   (1/1 Running)
# - rdi-operator-xxx          (1/1 Running)
# - rdi-reloader-xxx          (1/1 Running)

# Check Helm release
helm list -n rdi

# Check pipeline status (RDI 1.8.0+)
kubectl get pipeline -n rdi
```

### Check Logs

```bash
# RDI Operator logs
kubectl logs -n rdi -l app=rdi-operator --tail=100 -f

# RDI API logs
kubectl logs -n rdi -l app=rdi-api --tail=100 -f

# Collector logs
kubectl logs -n rdi -l app=rdi-collector --tail=100 -f

# Processor logs
kubectl logs -n rdi -l app=rdi-processor --tail=100 -f

# All RDI logs
kubectl logs -n rdi --all-containers=true --tail=100 -f
```

---

## 🚨 Common Issues

### 1. Pods not starting (CrashLoopBackOff)

**Symptoms:**
```bash
kubectl get pods -n rdi
# NAME                    READY   STATUS             RESTARTS
# rdi-api-xxx             0/1     CrashLoopBackOff   5
```

**Causes and Solutions:**

**A. RDI Database not accessible**

```bash
# Check logs
kubectl logs -n rdi -l app=rdi-api --tail=50

# Look for errors like:
# "Failed to connect to RDI database"
# "Connection refused"

# Verify RDI database
kubectl get redb rdi-database -n redis-enterprise
kubectl get secret redb-rdi-database -n redis-enterprise

# Test connectivity
kubectl run -it --rm debug --image=redis:latest --restart=Never -n rdi -- \
  redis-cli -h rdi-database.redis-enterprise.svc.cluster.local -p 12100 -a PASSWORD PING
```

**B. RDI Database is clustered (CRITICAL)**

```bash
# Check if database is clustered
kubectl get redb rdi-database -n redis-enterprise -o jsonpath='{.spec.shardCount}'
# Should be: 1

# If > 1, database is clustered - RDI WILL NOT WORK
# Solution: Delete and recreate database with shardCount: 1
kubectl delete redb rdi-database -n redis-enterprise
kubectl apply -f 01-rdi-database.yaml
```

**C. Invalid TLS certificates**

```bash
# Check TLS configuration in values.yaml
# Verify certificates are valid and not expired

# Test TLS connection
openssl s_client -connect rdi-database.redis-enterprise.svc.cluster.local:12100 \
  -CAfile ca.crt -cert client.crt -key client.key
```

**D. OpenShift SCC issues**

```bash
# Check pod security context
kubectl get pod -n rdi -o jsonpath='{.items[0].spec.securityContext}'

# Verify runAsUser is in valid range
oc get projects rdi -o yaml | grep "openshift.io/sa.scc"

# Update values.yaml with correct runAsUser/runAsGroup
```

---

### 2. Pipeline not starting

**Symptoms:**
- Pipeline status: FAILED or STOPPED
- Collector not connecting to source database

**Diagnosis:**

```bash
# Check pipeline status (via Redis Insight or CLI)
redis-di status --rdi-host rdi-api.rdi.svc.cluster.local:8080

# Check collector logs
kubectl logs -n rdi -l app=rdi-collector --tail=100

# Common errors:
# - "Failed to connect to source database"
# - "Authentication failed"
# - "SSL connection error"
```

**Solutions:**

**A. Source database not prepared for CDC**

```bash
# Verify source database configuration
# See: 08-source-database-prep.md

# PostgreSQL: Check wal_level
psql -h source-db -U postgres -c "SHOW wal_level;"  # Should be 'logical'

# MySQL: Check binlog_format
mysql -h source-db -u root -p -e "SHOW VARIABLES LIKE 'binlog_format';"  # Should be 'ROW'

# Oracle: Check supplemental logging
sqlplus / as sysdba
SELECT supplemental_log_data_min FROM v$database;  # Should be 'YES'
```

**B. Incorrect credentials**

```bash
# Test source database connection manually
# PostgreSQL
psql -h source-db -U rdi_user -d database_name

# MySQL
mysql -h source-db -u rdi_user -p database_name

# Verify credentials in RDI configuration
```

**C. Network connectivity**

```bash
# Test connectivity from RDI pod
kubectl run -it --rm debug --image=busybox --restart=Never -n rdi -- \
  nc -zv source-db-host 5432

# Check network policies
kubectl get networkpolicy -n rdi
```

---

### 3. Data not replicating

**Symptoms:**
- Pipeline is RUNNING
- But data doesn't appear in Redis

**Diagnosis:**

```bash
# Check collector metrics
kubectl port-forward -n rdi svc/rdi-metric-exporter 8081:8081
curl http://localhost:8081/metrics/collector-source | grep -E "(Connected|NumberOfEvents)"

# Check processor metrics
curl http://localhost:8081/metrics/rdi | grep -E "(processed|rejected)"

# Check processor logs
kubectl logs -n rdi -l app=rdi-processor --tail=100
```

**Solutions:**

**A. Filters blocking data**

```bash
# Review jobs/*.yaml
# Check if there are filters blocking data

# Example of filter that blocks everything:
# - uses: filter
#   with:
#     expression: false  # BLOCKS EVERYTHING!
```

**B. Transformations with errors**

```bash
# Check processor logs
kubectl logs -n rdi -l app=rdi-processor --tail=100 | grep ERROR

# Look for:
# - "Transformation failed"
# - "Invalid expression"
# - "Field not found"
```

**C. Redis target not accessible**

```bash
# Test connection to Redis target
kubectl run -it --rm debug --image=redis:latest --restart=Never -n rdi -- \
  redis-cli -h redis-database.redis-enterprise.svc.cluster.local -p 12000 -a PASSWORD PING

# Verify credentials in config.yaml
```

---

## 📊 RDI Logs

### Log Configuration

RDI uses **fluentd** and **logrotate** for log management.

**Default configuration:**
- **Location**: `/opt/rdi/logs` (on host VM)
- **Level**: INFO (minimum)
- **Rotation**: 100MB per file
- **Retention**: Last 5 rotated files
- **Format**: Plain text

### Change Log Configuration

```bash
# Via RDI CLI
redis-di configure-rdi \
  --rdi-host rdi-api.rdi.svc.cluster.local:8080 \
  --log-level DEBUG \
  --log-max-size 200MB \
  --log-max-files 10
```

---

## 🆘 Dump Support Package

To send comprehensive forensics data to Redis support:

```bash
# Via RDI CLI
redis-di dump-support-package \
  --rdi-host rdi-api.rdi.svc.cluster.local:8080 \
  --output /tmp/rdi-support-package.tar.gz

# Package includes:
# - Logs from all components
# - Pipeline configuration
# - Current metrics
# - RDI database state
# - Kubernetes information (pods, services, etc.)
```

---

## ✅ Troubleshooting Checklist

### Before opening support ticket:

- [ ] Check logs from all RDI pods
- [ ] Check Prometheus metrics
- [ ] Verify source database configuration (CDC enabled)
- [ ] Verify network connectivity
- [ ] Check pod resources (CPU/memory)
- [ ] Collect support package
- [ ] Document steps to reproduce the issue

---

## 🔗 Useful Links

- [RDI Troubleshooting](https://redis.io/docs/latest/integrate/redis-data-integration/installation/troubleshooting/)
- [RDI Logs](https://redis.io/docs/latest/integrate/redis-data-integration/observability/logging/)
- [RDI Support](https://redis.io/support/)

