# EKS Storage Configuration

## Prerequisites

- EKS cluster running
- EBS CSI driver installed (default in EKS 1.23+)

---

## gp3 StorageClass (Recommended)

```bash
# Apply gp3 StorageClass
kubectl apply -f gp3-storageclass.yaml

# Set as default
kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove default from gp2 (if exists)
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Verify
kubectl get storageclass
```

**Why gp3:**
- ✅ Better performance (3000 IOPS baseline)
- ✅ Lower cost than gp2
- ✅ `WaitForFirstConsumer` binding mode (better for multi-AZ)

---

## io2 StorageClass (High Performance)

For production workloads requiring high IOPS:

```bash
kubectl apply -f io2-storageclass.yaml
```

**Use cases:**
- Production databases with high throughput requirements
- Low-latency requirements
- Consistent performance needed

---

## Verification

```bash
# Check StorageClasses
kubectl get storageclass

# Check default
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

---

## References

- [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [EBS Volume Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html)

