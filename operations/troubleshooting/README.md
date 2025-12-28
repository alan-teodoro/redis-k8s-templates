# Troubleshooting Guide for Redis Enterprise on Kubernetes

Comprehensive troubleshooting guide for common issues with Redis Enterprise on Kubernetes.

## 📋 Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Common Issues](#common-issues)
- [Cluster Issues](#cluster-issues)
- [Database Issues](#database-issues)
- [Performance Issues](#performance-issues)
- [Network Issues](#network-issues)
- [Storage Issues](#storage-issues)
- [Operator Issues](#operator-issues)

---

## 🔍 Quick Diagnostics

### Check Cluster Status

```bash
# Check REC status
kubectl get rec -n redis-enterprise

# Check REC details
kubectl describe rec rec -n redis-enterprise

# Check pods
kubectl get pods -n redis-enterprise

# Check pod logs
kubectl logs -n redis-enterprise rec-0 --tail=100
```

### Check Database Status

```bash
# Check REDB status
kubectl get redb -n redis-enterprise

# Check REDB details
kubectl describe redb redis-db -n redis-enterprise

# Check database from inside cluster
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status databases
```

### Check Events

```bash
# Check recent events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n redis-enterprise --watch
```

---

## 🔧 Common Issues

### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n redis-enterprise
# NAME    READY   STATUS             RESTARTS   AGE
# rec-0   0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs rec-0 -n redis-enterprise --previous

# Check pod events
kubectl describe pod rec-0 -n redis-enterprise
```

**Common Causes:**
1. **Insufficient resources**
   ```bash
   # Check node resources
   kubectl describe node <node-name>
   
   # Solution: Increase node resources or reduce pod requests
   ```

2. **Storage issues**
   ```bash
   # Check PVC status
   kubectl get pvc -n redis-enterprise
   
   # Solution: Ensure storage class exists and has capacity
   ```

3. **Configuration errors**
   ```bash
   # Check REC spec
   kubectl get rec rec -n redis-enterprise -o yaml
   
   # Solution: Fix configuration and reapply
   ```

---

### Issue: Database Not Accessible

**Symptoms:**
```bash
redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 PING
# Error: Connection refused
```

**Diagnosis:**
```bash
# Check database status
kubectl get redb redis-db -n redis-enterprise

# Check service
kubectl get svc -n redis-enterprise | grep redis-db

# Check endpoints
kubectl get endpoints redis-db -n redis-enterprise
```

**Solutions:**

1. **Database not ready**
   ```bash
   kubectl describe redb redis-db -n redis-enterprise
   # Wait for status: Active
   ```

2. **Service not created**
   ```bash
   # Check if service exists
   kubectl get svc redis-db -n redis-enterprise
   
   # If missing, check operator logs
   kubectl logs -n redis-enterprise -l name=redis-enterprise-operator
   ```

3. **Network policy blocking**
   ```bash
   # Check network policies
   kubectl get networkpolicy -n redis-enterprise
   
   # Temporarily disable to test
   kubectl delete networkpolicy deny-all -n redis-enterprise
   ```

---

### Issue: High Memory Usage

**Symptoms:**
```bash
kubectl top pods -n redis-enterprise
# NAME    CPU   MEMORY
# rec-0   500m  15Gi/16Gi  # 93% memory usage
```

**Diagnosis:**
```bash
# Check database memory usage
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status databases

# Check eviction policy
kubectl get redb redis-db -n redis-enterprise -o jsonpath='{.spec.evictionPolicy}'
```

**Solutions:**

1. **Increase memory limit**
   ```yaml
   spec:
     memorySize: 4GB  # Increase from 2GB
   ```

2. **Enable eviction**
   ```yaml
   spec:
     evictionPolicy: volatile-lru  # or allkeys-lru
   ```

3. **Add more shards**
   ```yaml
   spec:
     shardCount: 2  # Distribute data across shards
   ```

---

### Issue: Slow Performance

**Symptoms:**
- High latency
- Slow queries
- Timeouts

**Diagnosis:**
```bash
# Check CPU usage
kubectl top pods -n redis-enterprise

# Check slow log
kubectl exec -it rec-0 -n redis-enterprise -- redis-cli -p 12000 SLOWLOG GET 10

# Check network latency
kubectl exec -it rec-0 -n redis-enterprise -- ping redis-db.redis-enterprise.svc.cluster.local
```

**Solutions:**

1. **Increase CPU**
   ```yaml
   spec:
     redisEnterpriseNodeResources:
       requests:
         cpu: "4"  # Increase from 2
   ```

2. **Enable pipelining**
   ```bash
   # Use pipelining in client
   redis-cli --pipe < commands.txt
   ```

3. **Check network policies**
   ```bash
   # Ensure network policies allow traffic
   kubectl get networkpolicy -n redis-enterprise
   ```

---

### Issue: Backup Failures

**Symptoms:**
```bash
kubectl logs rec-0 -n redis-enterprise | grep backup
# ERROR: Failed to upload backup to S3
```

**Diagnosis:**
```bash
# Check backup configuration
kubectl get redb redis-db -n redis-enterprise -o jsonpath='{.spec.backup}'

# Check S3 credentials
kubectl get secret -n redis-enterprise | grep s3

# Test S3 access
kubectl exec -it rec-0 -n redis-enterprise -- \
  aws s3 ls s3://redis-backups/
```

**Solutions:**

1. **Fix S3 credentials**
   ```bash
   # Update secret with correct credentials
   kubectl create secret generic s3-credentials \
     --from-literal=AWS_ACCESS_KEY_ID=xxx \
     --from-literal=AWS_SECRET_ACCESS_KEY=yyy \
     -n redis-enterprise --dry-run=client -o yaml | kubectl apply -f -
   ```

2. **Check IAM permissions**
   ```bash
   # Ensure IAM role has s3:PutObject permission
   ```

3. **Verify bucket exists**
   ```bash
   aws s3 mb s3://redis-backups
   ```

---

### Issue: Certificate Errors

**Symptoms:**
```bash
kubectl logs rec-0 -n redis-enterprise | grep certificate
# ERROR: Certificate verification failed
```

**Diagnosis:**
```bash
# Check certificate secrets
kubectl get secret -n redis-enterprise | grep cert

# Check certificate expiry
kubectl get secret rec-api-cert -n redis-enterprise -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates
```

**Solutions:**

1. **Renew certificate**
   ```bash
   # If using cert-manager, it should auto-renew
   kubectl get certificate -n redis-enterprise
   
   # Force renewal
   kubectl delete certificate rec-api-cert -n redis-enterprise
   kubectl apply -f rec-certificates.yaml
   ```

2. **Update certificate secret**
   ```bash
   # Create new certificate secret
   kubectl create secret tls rec-api-cert \
     --cert=path/to/cert.pem \
     --key=path/to/key.pem \
     -n redis-enterprise
   ```

---

## 📚 Related Documentation

- [Monitoring](../../observability/monitoring/README.md)
- [Logging](../../observability/logging/README.md)
- [HA & DR](../ha-disaster-recovery/README.md)

---

## 🔗 References

- Redis Enterprise Troubleshooting: https://redis.io/docs/latest/operate/rs/installing-upgrading/install/troubleshooting/
- Kubernetes Troubleshooting: https://kubernetes.io/docs/tasks/debug/

