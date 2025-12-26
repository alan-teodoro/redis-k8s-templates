# AKS Storage Configuration

Storage configuration for Redis Enterprise on Azure Kubernetes Service (AKS).

---

## Overview

AKS uses **Azure Disk CSI Driver** for persistent storage.

**Default:** AKS 1.21+ includes the CSI driver by default.

---

## Storage Class Options

### managed-csi-premium (Recommended for Production)

Premium SSD storage.

**Characteristics:**
- ✅ High IOPS (up to 20,000)
- ✅ Low latency
- ✅ Production workloads
- ❌ Higher cost

**File:** `managed-csi-premium-storageclass.yaml`

**Status:** 🚧 Coming soon

### managed-csi (Recommended for Dev/Test)

Standard SSD storage.

**Characteristics:**
- ✅ Good performance (up to 6,000 IOPS)
- ✅ Lower cost than premium
- ✅ Dev/test workloads
- ✅ Most common use case

**File:** `managed-csi-storageclass.yaml`

**Status:** 🚧 Coming soon

---

## Installation

### Check CSI Driver

```bash
# Check if CSI driver is installed (should be default in AKS 1.21+)
kubectl get pods -n kube-system | grep csi-azuredisk
```

### Enable CSI Driver (if not installed)

```bash
# Enable Azure Disk CSI driver
az aks update \
  --name <cluster-name> \
  --resource-group <resource-group> \
  --enable-disk-driver
```

### Apply Storage Class

```bash
# For production (premium SSD)
kubectl apply -f managed-csi-premium-storageclass.yaml

# For dev/test (standard SSD)
kubectl apply -f managed-csi-storageclass.yaml

# Set as default
kubectl patch storageclass managed-csi-premium -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## Example Storage Class (managed-csi-premium)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  kind: Managed
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

## Troubleshooting

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n redis-enterprise

# Check events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'

# Check storage class
kubectl get storageclass
```

### CSI Driver Not Found

```bash
# Check CSI driver pods
kubectl get pods -n kube-system | grep csi-azuredisk

# If not found, enable it
az aks update --name <cluster-name> --resource-group <resource-group> --enable-disk-driver
```

---

## References

- [Azure Disk CSI Driver](https://docs.microsoft.com/en-us/azure/aks/azure-disk-csi)
- [AKS Storage Classes](https://docs.microsoft.com/en-us/azure/aks/concepts-storage)
- [Azure Disk Types](https://docs.microsoft.com/en-us/azure/virtual-machines/disks-types)

