# Storage Class Validation for Redis Enterprise

**CRITICAL:** Redis Enterprise requires **block storage only**. NFS and other network file systems are **NOT supported** and will cause data corruption and performance issues.

---

## ✅ Supported Storage Types

### AWS EKS

**✅ SUPPORTED (Block Storage):**
- **EBS gp3** (recommended) - General Purpose SSD
- **EBS gp2** - General Purpose SSD (older generation)
- **EBS io1/io2** - Provisioned IOPS SSD (high performance)
- **EBS st1** - Throughput Optimized HDD (not recommended for production)

**❌ NOT SUPPORTED:**
- **EFS (Elastic File System)** - NFS-based, NOT supported
- **FSx for Lustre** - Network file system, NOT supported
- **FSx for NetApp ONTAP** - NFS/SMB, NOT supported

### Azure AKS

**✅ SUPPORTED (Block Storage):**
- **Azure Disk (managed-premium)** (recommended) - Premium SSD
- **Azure Disk (managed)** - Standard SSD
- **Azure Disk (managed-csi)** - CSI driver for Azure Disk

**❌ NOT SUPPORTED:**
- **Azure Files** - SMB/NFS-based, NOT supported
- **Azure NetApp Files** - NFS-based, NOT supported

### Google GKE

**✅ SUPPORTED (Block Storage):**
- **Persistent Disk (pd-ssd)** (recommended) - SSD
- **Persistent Disk (pd-standard)** - Standard HDD
- **Persistent Disk (pd-balanced)** - Balanced SSD

**❌ NOT SUPPORTED:**
- **Filestore** - NFS-based, NOT supported

---

## 🔍 How to Validate Your StorageClass

### Step 1: List Available StorageClasses

```bash
kubectl get storageclass
```

**Example output (EKS):**
```
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   true                   30d
gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   30d
efs-sc          efs.csi.aws.com         Delete          Immediate              false                  10d
```

### Step 2: Check StorageClass Provisioner

```bash
kubectl get storageclass gp3 -o yaml
```

**Look for the `provisioner` field:**

**✅ GOOD (Block Storage):**
```yaml
provisioner: ebs.csi.aws.com              # ✅ AWS EBS (block)
provisioner: kubernetes.io/aws-ebs        # ✅ AWS EBS (block, legacy)
provisioner: disk.csi.azure.com           # ✅ Azure Disk (block)
provisioner: kubernetes.io/azure-disk     # ✅ Azure Disk (block, legacy)
provisioner: pd.csi.storage.gke.io        # ✅ GCP Persistent Disk (block)
provisioner: kubernetes.io/gce-pd         # ✅ GCP Persistent Disk (block, legacy)
```

**❌ BAD (Network File Systems - NOT SUPPORTED):**
```yaml
provisioner: efs.csi.aws.com              # ❌ AWS EFS (NFS)
provisioner: file.csi.azure.com           # ❌ Azure Files (SMB/NFS)
provisioner: netapp.io/trident            # ❌ NetApp (NFS)
provisioner: nfs.csi.k8s.io               # ❌ Generic NFS
```

### Step 3: Verify REC is Using Correct StorageClass

```bash
# Check PVCs created by REC
kubectl get pvc -n redis-enterprise

# Check PVC details
kubectl describe pvc redis-enterprise-storage-rec-0 -n redis-enterprise
```

**Look for:**
```
StorageClass:  gp3  # ✅ Should be block storage (gp3, pd-ssd, managed-premium, etc.)
```

**If you see:**
```
StorageClass:  efs-sc  # ❌ WRONG! This is NFS-based
```

**You MUST change the StorageClass before deploying Redis Enterprise!**

---

## 🛠️ How to Fix Wrong StorageClass

### If REC is NOT Yet Deployed

Simply specify the correct StorageClass in your REC manifest:

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec
  namespace: redis-enterprise
spec:
  nodes: 3
  persistentSpec:
    enabled: true
    storageClassName: gp3  # ✅ Use block storage
    volumeSize: 100Gi
```

### If REC is Already Deployed with Wrong StorageClass

**⚠️ WARNING:** You CANNOT change PVC StorageClass after deployment without data loss.

**Options:**

1. **Delete and recreate cluster** (data loss):
   ```bash
   kubectl delete rec rec -n redis-enterprise
   # Wait for PVCs to be deleted
   kubectl get pvc -n redis-enterprise
   # Recreate with correct StorageClass
   kubectl apply -f rec-corrected.yaml
   ```

2. **Backup, delete, restore** (no data loss):
   ```bash
   # 1. Backup all databases to S3/GCS/Azure
   # 2. Delete cluster
   kubectl delete rec rec -n redis-enterprise
   # 3. Recreate with correct StorageClass
   kubectl apply -f rec-corrected.yaml
   # 4. Restore databases from backup
   ```

---

## 🚨 Common Mistakes

### Mistake 1: Using Default StorageClass Without Checking

```bash
# ❌ DON'T assume default StorageClass is block storage
kubectl get storageclass
# Check what the default is!
```

**Solution:** Always explicitly specify `storageClassName` in REC manifest.

### Mistake 2: Using EFS on AWS

```yaml
# ❌ WRONG - EFS is NFS-based
persistentSpec:
  storageClassName: efs-sc
```

**Solution:** Use EBS (gp3, gp2, io1, io2):
```yaml
# ✅ CORRECT - EBS is block storage
persistentSpec:
  storageClassName: gp3
```

### Mistake 3: Using Azure Files on AKS

```yaml
# ❌ WRONG - Azure Files is SMB/NFS-based
persistentSpec:
  storageClassName: azurefile
```

**Solution:** Use Azure Disk:
```yaml
# ✅ CORRECT - Azure Disk is block storage
persistentSpec:
  storageClassName: managed-premium
```

---

## ✅ Validation Checklist

Before deploying Redis Enterprise, verify:

- [ ] StorageClass provisioner is block storage (EBS, Azure Disk, Persistent Disk)
- [ ] StorageClass is NOT NFS-based (EFS, Azure Files, Filestore, NetApp)
- [ ] StorageClass supports volume expansion (`allowVolumeExpansion: true`)
- [ ] StorageClass has appropriate performance tier (SSD recommended)
- [ ] REC manifest explicitly specifies `storageClassName`
- [ ] Tested PVC creation with the StorageClass

---

## 📚 Related Documentation

- [AWS EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [Azure Disk CSI Driver](https://learn.microsoft.com/en-us/azure/aks/azure-disk-csi)
- [GCP Persistent Disk CSI Driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver)
- [Redis Enterprise Storage Requirements](https://redis.io/docs/latest/operate/rs/installing-upgrading/install/plan-deployment/persistent-ephemeral-storage/)

