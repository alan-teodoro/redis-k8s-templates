# Redis on Flash - Troubleshooting

Common issues and solutions for Redis on Flash deployments.

---

## Common Issues

### 1. REDB Not Starting with Flash

**Symptom**:
```bash
kubectl get redb flash-db -n redis-enterprise
# STATUS: Pending (stuck)
```

**Possible Causes**:

#### A) REC Does Not Have Flash Enabled

**Check**:
```bash
kubectl get rec -n redis-enterprise -o yaml | grep -A5 redisOnFlashSpec
```

**Solution**:
```bash
# Edit REC to enable RoF
kubectl edit rec -n redis-enterprise

# Add:
spec:
  redisOnFlashSpec:
    enabled: true
    flashStorageEngine: rocksdb
    flashDiskSize: 500Gi
```

#### B) StorageClass Does Not Exist

**Check**:
```bash
kubectl get storageclass
```

**Solution**:
```bash
# Create appropriate StorageClass
kubectl apply -f 01-storage-class-aws.yaml  # or azure/gcp
```

#### C) PVC Cannot Be Created

**Check**:
```bash
kubectl get pvc -n redis-enterprise
kubectl describe pvc <pvc-name> -n redis-enterprise
```

**Solution**:
- Verify StorageClass exists and is correct
- Check node has available storage
- Verify CSI driver is installed

---

### 2. Poor Performance (High Latency)

**Symptom**: P95 latency > 5ms

**Possible Causes**:

#### A) Using Network-Attached Storage

**Check**:
```bash
kubectl get pvc -n redis-enterprise -o yaml | grep storageClassName
```

**Solution**:
- **DO NOT use RoF with EBS/Azure Disk/GCP PD**
- Migrate to instances with NVMe local SSD
- Or switch to RAM-only deployment

#### B) Low RAM Hit Ratio

**Check**:
```bash
# Check metrics in Grafana or via rladmin
kubectl exec -n redis-enterprise rec-0 -- rladmin status databases
```

**Solution**:
- Increase RAM allocation
- Reduce working set size
- Implement TTLs on cold data

---

### 3. Flash Storage Full

**Symptom**: Database evicting data unexpectedly

**Check**:
```bash
kubectl exec -n redis-enterprise rec-0 -- rladmin status databases
# Look for flash usage percentage
```

**Solution**:
```bash
# Increase flash size
kubectl edit redb flash-db -n redis-enterprise

# Update:
spec:
  redisOnFlashSpec:
    flashDiskSize: 1000Gi  # Increase from 500Gi
```

---

### 4. REC Pods Not Starting

**Symptom**: REC pods stuck in Pending

**Check**:
```bash
kubectl get pods -n redis-enterprise
kubectl describe pod rec-0 -n redis-enterprise
```

**Possible Causes**:

#### A) Insufficient Node Resources

**Solution**:
- Add more nodes to cluster
- Use larger instance types
- Reduce REC resource requests

#### B) PVC Not Binding

**Check**:
```bash
kubectl get pvc -n redis-enterprise
```

**Solution**:
- Verify StorageClass exists
- Check available storage on nodes
- Verify CSI driver is running

---

## Diagnostic Commands

### Check REC Status
```bash
kubectl get rec -n redis-enterprise
kubectl describe rec -n redis-enterprise
```

### Check REDB Status
```bash
kubectl get redb -n redis-enterprise
kubectl describe redb flash-db -n redis-enterprise
```

### Check Flash Configuration
```bash
kubectl exec -n redis-enterprise rec-0 -- rladmin status databases
```

### Check Operator Logs
```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

### Check REC Logs
```bash
kubectl logs -n redis-enterprise rec-0
```

---

## Getting Help

If issues persist:

1. Collect diagnostic information:
```bash
kubectl get all -n redis-enterprise
kubectl describe rec -n redis-enterprise
kubectl describe redb -n redis-enterprise
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=200
```

2. Check Redis Enterprise documentation:
   - [Redis on Flash Troubleshooting](https://docs.redis.com/latest/rs/databases/redis-on-flash/rof-troubleshooting/)

3. Contact Redis Support with collected information
