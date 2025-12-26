# GKE Storage Configuration

Storage configuration for Redis Enterprise on Google Kubernetes Engine (GKE).

---

## Overview

GKE uses **GCE Persistent Disk CSI Driver** for persistent storage.

**Default:** GKE 1.18+ includes the CSI driver by default.

---

## Storage Class Options

### pd-ssd (Recommended for Production)

High-performance SSD storage.

**Characteristics:**
- ✅ High IOPS (up to 30,000)
- ✅ Low latency
- ✅ Production workloads
- ❌ Higher cost

**File:** `pd-ssd-storageclass.yaml`

**Status:** 🚧 Coming soon

### pd-balanced (Recommended for Dev/Test)

Balanced performance and cost.

**Characteristics:**
- ✅ Good performance (up to 6,000 IOPS)
- ✅ Lower cost than pd-ssd
- ✅ Dev/test workloads
- ✅ Most common use case

**File:** `pd-balanced-storageclass.yaml`

**Status:** 🚧 Coming soon

---

## Installation

### Check CSI Driver

```bash
# Check if CSI driver is installed (should be default in GKE 1.18+)
kubectl get pods -n kube-system | grep csi-gce-pd
```

### Apply Storage Class

```bash
# For production (pd-ssd)
kubectl apply -f pd-ssd-storageclass.yaml

# For dev/test (pd-balanced)
kubectl apply -f pd-balanced-storageclass.yaml

# Set as default
kubectl patch storageclass pd-ssd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## Example Storage Class (pd-ssd)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd  # or none for zonal
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
kubectl get pods -n kube-system | grep csi-gce-pd

# If not found, upgrade GKE cluster to 1.18+
```

---

## References

- [GCE Persistent Disk CSI Driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver)
- [GKE Storage Classes](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes)
- [Persistent Disk Types](https://cloud.google.com/compute/docs/disks#disk-types)

