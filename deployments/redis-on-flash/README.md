# Redis on Flash (RoF)

⚠️ **IMPORTANT LIMITATION - REQUIRES SPECIFIC HARDWARE**

**Redis on Flash requires NVMe SSD storage and is NOT recommended for testing on standard EKS/cloud environments.**

Redis on Flash (RoF) is designed for production workloads with:
- **NVMe SSD storage** (not standard EBS/cloud disks)
- **Large datasets** (> 100GB)
- **Cost optimization** requirements

**For EKS testing, this deployment pattern is SKIPPED** as it requires specialized storage that is not cost-effective for validation purposes.

---

## Overview

### What is Redis on Flash?

**Redis on Flash (RoF)** is a Redis Enterprise technology that stores data across **RAM + SSD** using intelligent tiering:

- **Hot data** (frequently accessed) → **RAM** (ultra-low latency)
- **Warm data** (less frequently accessed) → **SSD/Flash** (low latency, reduced cost)

### Benefits

| Benefit | Description |
|---------|-------------|
| **Cost Reduction** | Up to 70% savings vs. RAM-only for large datasets |
| **Higher Capacity** | TB-scale datasets at fraction of RAM cost |
| **Performance** | Hot data in RAM maintains sub-millisecond latency |
| **Automatic Tiering** | Redis automatically manages hot/warm data |
| **Transparent** | No application changes required |

### Ideal Use Cases

- **Session Store** with millions of sessions (mostly inactive)
- **Cache** with small working set but large total dataset
- **Time-Series** with recent hot data and historical cold data
- **Analytics** with queries on recent data
- **Leaderboards** with millions of users but only top-N accessed

---

## When to Use

### Use Redis on Flash when:

- Total dataset > 100GB
- Working set (hot data) < 30% of total dataset
- Large values (> 1KB)
- 1-5ms latency acceptable for warm data
- Cost is critical factor
- **NVMe SSD storage available**

### DO NOT use Redis on Flash when:

- Total dataset < 50GB (RAM-only is simpler)
- All data is hot (100% working set)
- Sub-millisecond latency required for all data
- Small values (< 500 bytes)
- **Standard cloud storage (EBS, Azure Disk, GCP PD)** - performance will be poor

---

## Prerequisites

### 1. Storage Requirements

**CRITICAL:** Redis on Flash requires high-performance NVMe SSD storage.

**AWS:**
- Instance types with NVMe SSD: `i3`, `i3en`, `i4i`, `im4gn`, `is4gen`
- **NOT recommended:** EBS volumes (gp2, gp3, io1, io2) - too slow for RoF

**Azure:**
- VM types with NVMe SSD: `Lsv2`, `Lsv3`
- **NOT recommended:** Premium SSD, Ultra Disk - too slow for RoF

**GCP:**
- Instance types with local SSD: `n2-standard` with local SSD
- **NOT recommended:** Persistent Disk (pd-ssd, pd-extreme) - too slow for RoF

### 2. Kubernetes Cluster

```bash
kubectl version --short
```

### 3. Redis Enterprise Operator and REC

```bash
kubectl get deployment redis-enterprise-operator -n redis-enterprise
kubectl get rec -n redis-enterprise
```

---

## Deployment Guide (Production Only)

⚠️ **This guide is for PRODUCTION deployments with proper NVMe SSD storage.**

### Step 1: Create StorageClass

Choose the appropriate StorageClass for your cloud provider:

**AWS (i3/i3en/i4i instances with NVMe):**
```bash
kubectl apply -f 01-storage-class-aws.yaml
```

**Azure (Lsv2/Lsv3 VMs with NVMe):**
```bash
kubectl apply -f 01-storage-class-azure.yaml
```

**GCP (instances with local SSD):**
```bash
kubectl apply -f 01-storage-class-gcp.yaml
```

### Step 2: Deploy REC with Flash Storage

```bash
kubectl apply -f 02-rec-with-flash.yaml
```

Wait for REC to be ready:
```bash
kubectl get rec -n redis-enterprise -w
```

### Step 3: Deploy REDB with Flash

```bash
kubectl apply -f 03-redb-with-flash.yaml
```

Wait for REDB to be active:
```bash
kubectl wait --for=jsonpath='{.status.status}'=active redb/flash-db -n redis-enterprise --timeout=300s
```

### Step 4: Verify Flash Configuration

```bash
kubectl get redb flash-db -n redis-enterprise
kubectl exec -n redis-enterprise rec-0 -- rladmin status databases
```

---

## Performance Tuning

See [04-performance-tuning.md](./04-performance-tuning.md)

---

## Troubleshooting

See [05-troubleshooting.md](./05-troubleshooting.md)

---

## Cleanup

```bash
kubectl delete -f 03-redb-with-flash.yaml
kubectl delete -f 02-rec-with-flash.yaml
kubectl delete -f 01-storage-class-aws.yaml
```

