# Troubleshooting Guide for Redis Enterprise on Kubernetes

Comprehensive troubleshooting guide for common issues with Redis Enterprise on Kubernetes.

## 📋 Table of Contents

- [Forbidden Actions](#-forbidden-actions-never-do-this)
- [Quick Diagnostics](#quick-diagnostics)
- [Common Issues](#common-issues)
- [Cluster Issues](#cluster-issues)
- [Database Issues](#database-issues)
- [Performance Issues](#performance-issues)
- [Network Issues](#network-issues)
- [Storage Issues](#storage-issues)
- [Operator Issues](#operator-issues)

---

## ⛔ FORBIDDEN ACTIONS (NEVER DO THIS!)

**These actions can cause catastrophic failures, data loss, or cluster corruption. NEVER do any of these:**

### 🚨 Critical - Will Break Cluster

1. **❌ NEVER scale REC StatefulSet to 0**
   ```bash
   # ❌ DON'T DO THIS - Will destroy cluster!
   kubectl scale statefulset rec --replicas=0 -n redis-enterprise
   ```
   **Why:** This stops all Redis Enterprise pods simultaneously, breaking quorum and potentially corrupting data.

   **Instead:** If you need to delete the cluster, use proper deletion:
   ```bash
   # ✅ Proper way to delete cluster
   kubectl delete rec rec -n redis-enterprise
   ```

2. **❌ NEVER force-delete REC pods**
   ```bash
   # ❌ DON'T DO THIS - Can corrupt cluster state!
   kubectl delete pod rec-0 --force --grace-period=0 -n redis-enterprise
   ```
   **Why:** Force deletion bypasses graceful shutdown, can corrupt data and cluster state.

   **Instead:** Let pods terminate gracefully:
   ```bash
   # ✅ Proper way to delete pod
   kubectl delete pod rec-0 -n redis-enterprise
   # Wait for graceful termination (may take 30-60 seconds)
   ```

3. **❌ NEVER edit REC StatefulSet directly**
   ```bash
   # ❌ DON'T DO THIS - Operator will revert changes!
   kubectl edit statefulset rec -n redis-enterprise
   ```
   **Why:** The operator manages the StatefulSet. Manual changes will be reverted and can cause conflicts.

   **Instead:** Edit the REC custom resource:
   ```bash
   # ✅ Proper way to modify cluster
   kubectl edit rec rec -n redis-enterprise
   ```

4. **❌ NEVER take down a pod before all pods are ready**
   ```bash
   # ❌ DON'T DO THIS - Can break quorum!
   kubectl delete pod rec-0 -n redis-enterprise
   # Immediately deleting rec-1 before rec-0 is back
   kubectl delete pod rec-1 -n redis-enterprise
   ```
   **Why:** This can break quorum (need 2 out of 3 pods for majority).

   **Instead:** Wait for pod to be ready before proceeding:
   ```bash
   # ✅ Proper way to restart pods
   kubectl delete pod rec-0 -n redis-enterprise
   kubectl wait --for=condition=ready pod/rec-0 -n redis-enterprise --timeout=300s
   # Now safe to proceed to next pod
   kubectl delete pod rec-1 -n redis-enterprise
   ```

5. **❌ NEVER drain multiple nodes simultaneously**
   ```bash
   # ❌ DON'T DO THIS - Will break quorum!
   kubectl drain node1 node2 node3 --ignore-daemonsets
   ```
   **Why:** Draining multiple nodes at once can evict multiple REC pods, breaking quorum.

   **Instead:** Drain nodes one at a time:
   ```bash
   # ✅ Proper way to drain nodes
   kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
   kubectl wait --for=condition=ready pod -l app=redis-enterprise -n redis-enterprise --timeout=300s
   kubectl drain node2 --ignore-daemonsets --delete-emptydir-data
   kubectl wait --for=condition=ready pod -l app=redis-enterprise -n redis-enterprise --timeout=300s
   ```

### 🚨 Critical - Database Management

6. **❌ NEVER create databases via Admin UI or API when using REDB**
   ```bash
   # ❌ DON'T DO THIS - Creates configuration drift!
   # Creating database via UI or curl to API
   ```
   **Why:** When using REDB CRD, the REDB manifest is the source of truth. Creating databases via UI/API causes drift.

   **Instead:** Always use REDB CRD:
   ```bash
   # ✅ Proper way to create database
   kubectl apply -f redb.yaml
   ```

   **Exception:** Only use UI/API for features not yet supported in REDB CRD.

7. **❌ NEVER change PVC after deployment**
   ```bash
   # ❌ DON'T DO THIS - Can cause data loss!
   kubectl edit pvc redis-enterprise-storage-rec-0 -n redis-enterprise
   ```
   **Why:** Changing PVC can cause data loss or corruption.

   **Note:** PVC changes are possible from Redis Enterprise 7.4+, but should be avoided.

### 🚨 Critical - Storage

8. **❌ NEVER use NFS for persistence**
   ```yaml
   # ❌ DON'T DO THIS - NFS is not supported!
   persistentSpec:
     storageClassName: nfs-storage  # ❌ WRONG!
   ```
   **Why:** NFS has performance and consistency issues. Only block storage is supported.

   **Instead:** Use block storage:
   ```yaml
   # ✅ Use block storage (EBS, Persistent Disk, Azure Disk)
   persistentSpec:
     storageClassName: gp3  # ✅ AWS EBS
     # or: pd-ssd  # ✅ GCP Persistent Disk
     # or: managed-premium  # ✅ Azure Disk
   ```

### 🚨 Important - Operator Management

9. **❌ NEVER enable automatic operator upgrades (OpenShift OLM)**
   ```yaml
   # ❌ DON'T DO THIS in OLM subscription
   installPlanApproval: Automatic  # ❌ WRONG!
   ```
   **Why:** Automatic upgrades can happen during business hours, causing unexpected downtime.

   **Instead:** Use manual approval:
   ```yaml
   # ✅ Use manual approval for operator upgrades
   installPlanApproval: Manual  # ✅ CORRECT!
   ```

10. **❌ NEVER skip log collection practice**
    ```bash
    # ❌ DON'T wait for production issues to learn log_collector
    ```
    **Why:** In production incidents, you need to know how to collect logs quickly.

    **Instead:** Practice log collection in non-prod:
    ```bash
    # ✅ Practice log collection before issues occur
    kubectl exec -it rec-0 -n redis-enterprise -- /opt/redislabs/bin/rladmin cluster debug_info
    ```

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

