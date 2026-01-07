# GKE Implementation Review Checklist

**Platform:** Google Kubernetes Engine (GKE)  
**Date:** 2026-01-07  
**Simplified from:** `best-practices/IMPLEMENTATION-REVIEW-GUIDE.md`

---

## 📋 Pre-Meeting Information Needed

Request from client before meeting:

**GKE Cluster:**
- [ ] Cluster name and region
- [ ] GKE version
- [ ] Release channel (RAPID/REGULAR/STABLE)
- [ ] Autopilot or Standard?
- [ ] Number of zones
- [ ] Private or public cluster?

**Node Pools:**
- [ ] Machine type (e.g., n2-standard-8)
- [ ] Number of nodes
- [ ] Autoscaling enabled? (min/max)

**Redis Enterprise:**
- [ ] Operator version
- [ ] REC nodes (3 or 5?)
- [ ] CPU/Memory per REC node
- [ ] Storage class (pd-ssd or pd-balanced?)
- [ ] PVC size per node
- [ ] Number of databases
- [ ] Database configurations (memory, replication, persistence)

**Networking:**
- [ ] VPC name
- [ ] Subnet CIDR
- [ ] Firewall rules configured?
- [ ] Workload Identity enabled?

**Monitoring:**
- [ ] Prometheus/Grafana setup?
- [ ] Cloud Monitoring enabled?

---

## 1️⃣ GKE Cluster Configuration

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **GKE Version** | `gcloud container clusters describe <cluster> --region <region> --format="value(currentMasterVersion)"` | 1.27+ | < 1.25 |
| **Release Channel** | `gcloud container clusters describe <cluster> --region <region> --format="value(releaseChannel.channel)"` | REGULAR or STABLE | RAPID |
| **Cluster Type** | `gcloud container clusters describe <cluster> --region <region> --format="value(autopilot.enabled)"` | false (Standard) | true (Autopilot) for Redis |
| **Multi-Zone** | `kubectl get nodes -o custom-columns="ZONE:.metadata.labels.topology\.kubernetes\.io/zone"` | 3 zones | 1 zone |
| **Private Cluster** | `gcloud container clusters describe <cluster> --region <region> --format="value(privateClusterConfig.enablePrivateNodes)"` | true | false (for production) |

### **Critical Questions:**

**1. GKE Version & Release Channel?**
- Version 1.27+? ✅
- Release channel: REGULAR or STABLE? ✅
- ❌ RAPID channel (too unstable for production)

**2. Autopilot or Standard?**
- **Standard:** ✅ Recommended for Redis (full control)
- **Autopilot:** ⚠️ Limited control, may not fit Redis requirements

**3. Multi-Zone Deployment?**
- 3 zones? ✅ (e.g., us-central1-a, us-central1-b, us-central1-c)
- ❌ Single zone = single point of failure

**4. Private Cluster?**
- Private nodes? ✅ (recommended for production)
- Authorized networks configured? ✅

### **Commands:**
```bash
# Get cluster info
gcloud container clusters describe <cluster-name> --region <region>

# List zones
kubectl get nodes -o custom-columns="NODE:.metadata.name,ZONE:.metadata.labels.topology\.kubernetes\.io/zone"

# Check if private
gcloud container clusters describe <cluster-name> --region <region> \
  --format="value(privateClusterConfig.enablePrivateNodes)"
```

---

## 2️⃣ Node Pool Configuration

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **Dedicated Pool** | `gcloud container node-pools list --cluster <cluster> --region <region>` | Separate pool for Redis | Mixed workloads |
| **Machine Type** | `gcloud container node-pools describe <pool> --cluster <cluster> --region <region> --format="value(config.machineType)"` | n2-standard-8+ | e2, t2d (burstable) |
| **Node Count** | `gcloud container node-pools describe <pool> --cluster <cluster> --region <region> --format="value(initialNodeCount)"` | 3+ nodes | < 3 |
| **Autoscaling** | `gcloud container node-pools describe <pool> --cluster <cluster> --region <region> --format="value(autoscaling.enabled)"` | true | false |
| **Disk Type** | `gcloud container node-pools describe <pool> --cluster <cluster> --region <region> --format="value(config.diskType)"` | pd-ssd | pd-standard |

### **Critical Questions:**

**1. Dedicated Node Pool for Redis?**
- ✅ Separate pool with taints/tolerations
- ❌ Mixed with other workloads (resource contention)

**2. Machine Type?**
- **Recommended:**
  - n2-standard-8 (8 vCPU, 32GB RAM) ✅
  - n2-standard-16 (16 vCPU, 64GB RAM) ✅
- **Avoid:**
  - e2-* (burstable, unpredictable performance) ❌
  - t2d-* (burstable) ❌
  - n2-standard-2 or n2-standard-4 (too small) ❌

**3. Autoscaling Configured?**
- Min nodes: 3 ✅
- Max nodes: 6-10 ✅
- ❌ No autoscaling (can't handle growth)

**4. Boot Disk Type?**
- pd-ssd ✅ (faster boot, better performance)
- ❌ pd-standard (slower)

### **Commands:**
```bash
# List node pools
gcloud container node-pools list --cluster <cluster-name> --region <region>

# Get node pool details
gcloud container node-pools describe <pool-name> \
  --cluster <cluster-name> --region <region>

# Check actual nodes
kubectl get nodes -o wide
kubectl top nodes
```

---

## 3️⃣ Storage Configuration

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **CSI Driver** | `kubectl get pods -n kube-system \| grep csi-gce-pd` | Running | Not found |
| **Storage Class** | `kubectl get sc` | pd-ssd or premium-rwo | pd-standard |
| **Provisioner** | `kubectl get sc <name> -o jsonpath='{.provisioner}'` | pd.csi.storage.gke.io | kubernetes.io/gce-pd |
| **Volume Type** | `kubectl get sc <name> -o jsonpath='{.parameters.type}'` | pd-ssd or pd-balanced | pd-standard |
| **Reclaim Policy** | `kubectl get sc <name> -o jsonpath='{.reclaimPolicy}'` | Retain | Delete (production) |
| **Volume Expansion** | `kubectl get sc <name> -o jsonpath='{.allowVolumeExpansion}'` | true | false |

### **Critical Questions:**

**1. Storage Class?**
- **Production:** pd-ssd ✅
  - IOPS: 30/GB (up to 30,000)
  - Throughput: up to 1,200 MB/s
  - Cost: $0.17/GB/month
- **Dev/Test:** pd-balanced ⚠️
  - IOPS: 6/GB (up to 6,000)
  - Throughput: up to 240 MB/s
  - Cost: $0.10/GB/month
- **Never:** pd-standard ❌ (HDD, too slow)

**2. Using CSI Driver?**
- ✅ pd.csi.storage.gke.io (new)
- ❌ kubernetes.io/gce-pd (deprecated)

**3. Reclaim Policy?**
- **Production:** Retain ✅ (prevents accidental deletion)
- **Dev/Test:** Delete ⚠️

**4. Volume Expansion Enabled?**
- ✅ allowVolumeExpansion: true
- ❌ false (can't grow volumes)

### **Commands:**
```bash
# Check CSI driver
kubectl get pods -n kube-system | grep csi-gce-pd

# List storage classes
kubectl get storageclass

# Check storage class details
kubectl get sc <storage-class-name> -o yaml

# Check PVCs
kubectl get pvc -n redis-enterprise
```

---

## 4️⃣ Redis Enterprise Cluster (REC)

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **REC Exists** | `kubectl get rec -n redis-enterprise` | Running | Not found |
| **Number of Nodes** | `kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}'` | 3 or 5 | 2 or 4 |
| **CPU Limits** | `kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.cpu}'` | 4000m-8000m | < 2000m |
| **Memory Limits** | `kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}'` | 15Gi-30Gi | < 8Gi |
| **Limits = Requests** | `kubectl get rec -n redis-enterprise -o yaml \| grep -A2 limits` | limits = requests | limits > requests |
| **QoS Class** | `kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.status.qosClass}'` | Guaranteed | Burstable |
| **Storage Class** | `kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.persistentSpec.storageClassName}'` | pd-ssd | pd-standard |
| **Volume Size** | `kubectl get pvc -n redis-enterprise -o jsonpath='{.items[0].spec.resources.requests.storage}'` | 5x memory | < 5x memory |
| **Rack Awareness** | `kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.rackAwarenessNodeLabel}'` | topology.kubernetes.io/zone | empty |

### **Critical Questions:**

**1. Number of REC Nodes?**
- ✅ 3 nodes (can survive 1 failure)
- ✅ 5 nodes (can survive 2 failures)
- ❌ 2 nodes (no quorum on failure)
- ❌ 4 nodes (same fault tolerance as 3, wastes resources)

**2. CPU/Memory Allocation?**
- **Minimum:** 2000m CPU, 8Gi memory
- **Recommended:** 4000m-8000m CPU, 15Gi-30Gi memory
- **Limits = Requests?** ✅ (Guaranteed QoS)
- ❌ Limits > Requests (Burstable QoS, can be evicted)

**3. QoS Class?**
- ✅ **Guaranteed** (limits = requests)
  - Never evicted due to resource pressure
  - Dedicated CPU and memory
  - Predictable performance
- ❌ **Burstable** (limits > requests)
  - Can be evicted under pressure
  - Shares CPU with other pods
  - Unpredictable performance

**4. Volume Size (5x Memory Rule)?**
- **Why 5x?** Redis needs space for:
  - RDB snapshots (1x memory)
  - AOF files (1x memory)
  - Temporary files (1x memory)
  - OS overhead (1x memory)
  - Growth buffer (1x memory)
- **Example:** 15Gi memory → 75Gi volume
- ❌ < 5x = risk of disk full errors

**5. Rack Awareness Enabled?**
- ✅ topology.kubernetes.io/zone
  - Master and replica in different zones
  - Zone failure = automatic failover
- ❌ Not enabled
  - Master and replica could be in same zone
  - Zone failure = data loss

### **Commands:**
```bash
# Get REC status
kubectl get rec -n redis-enterprise

# Get REC configuration
kubectl get rec -n redis-enterprise -o yaml

# Quick validation
echo "Nodes: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}')"
echo "CPU: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.cpu}')"
echo "Memory: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}')"
echo "Storage Class: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.persistentSpec.storageClassName}')"

# Check pods
kubectl get pods -n redis-enterprise -l app=redis-enterprise -o wide

# Verify QoS
kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.status.qosClass}'

# Check PVCs
kubectl get pvc -n redis-enterprise

# Verify pod distribution across zones
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:.metadata.name,NODE:.spec.nodeName,ZONE:.spec.nodeSelector.topology\.kubernetes\.io/zone"
```

---

## 5️⃣ Database Configuration

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **Databases Exist** | `kubectl get redb -n redis-enterprise` | Running | Not found |
| **Memory Size** | `kubectl get redb <db> -n redis-enterprise -o jsonpath='{.spec.memorySize}'` | Appropriate | Too small |
| **Replication** | `kubectl get redb <db> -n redis-enterprise -o jsonpath='{.spec.replication}'` | true | false (production) |
| **Persistence** | `kubectl get redb <db> -n redis-enterprise -o jsonpath='{.spec.persistence}'` | aofEverySecond or snapshotEvery* | disabled |
| **TLS Enabled** | `kubectl get redb <db> -n redis-enterprise -o jsonpath='{.spec.tlsMode}'` | enabled or required | disabled |
| **Backup** | `kubectl get redb <db> -n redis-enterprise -o jsonpath='{.spec.backup}'` | Configured | null |

### **Critical Questions:**

**1. Replication Enabled?**
- ✅ true (high availability)
- ❌ false (single point of failure)

**2. Persistence Configured?**
- **Options:**
  - aofEverySecond ✅ (best durability)
  - snapshotEvery1Hour ✅ (less overhead)
  - snapshotEvery6Hour ⚠️ (up to 6h data loss)
  - disabled ❌ (cache only)

**3. TLS Enabled?**
- ✅ required (enforced encryption)
- ⚠️ enabled (optional encryption)
- ❌ disabled (no encryption)

**4. Backup Configured?**
- ✅ GCS bucket configured
- ❌ No backup (risky)

### **Commands:**
```bash
# List databases
kubectl get redb -n redis-enterprise

# Get database details
kubectl get redb <database-name> -n redis-enterprise -o yaml

# Check database status
kubectl describe redb <database-name> -n redis-enterprise
```

---

## 6️⃣ Networking & Security

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **Services** | `kubectl get svc -n redis-enterprise` | rec, rec-ui | Missing |
| **LoadBalancer IP** | `kubectl get svc rec -n redis-enterprise -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` | External IP | Pending |
| **Workload Identity** | `gcloud container clusters describe <cluster> --region <region> --format="value(workloadIdentityConfig.workloadPool)"` | <project>.svc.id.goog | null |
| **Service Account** | `kubectl get sa -n redis-enterprise -o yaml \| grep iam.gke.io/gcp-service-account` | Annotated | Not found |
| **Network Policy** | `kubectl get networkpolicy -n redis-enterprise` | Configured | None |

### **Critical Questions:**

**1. LoadBalancer Service?**
- ✅ External IP assigned
- ❌ Pending (check quotas, firewall)

**2. Workload Identity Enabled?**
- ✅ Enabled (for GCS backups, Secret Manager)
- ❌ Using service account keys (security risk)

**3. Firewall Rules?**
- Required ports:
  - 6379-6380 (databases)
  - 9443 (API)
  - 8443 (UI)
  - 8001 (metrics)

**4. Network Policies?**
- ✅ Configured (restrict traffic)
- ❌ None (security risk)

### **Commands:**
```bash
# Check services
kubectl get svc -n redis-enterprise

# Check LoadBalancer IP
kubectl get svc rec -n redis-enterprise

# Check Workload Identity
gcloud container clusters describe <cluster-name> --region <region> \
  --format="value(workloadIdentityConfig.workloadPool)"

# Check service account annotation
kubectl get sa -n redis-enterprise -o yaml | grep iam.gke.io/gcp-service-account

# Check network policies
kubectl get networkpolicy -n redis-enterprise
```

---

## 7️⃣ Monitoring & Observability

### **Validation Checklist:**

| Check | Command | Expected | Red Flag |
|-------|---------|----------|----------|
| **Prometheus** | `kubectl get pods -n redis-enterprise \| grep prom` | Running | Not found |
| **Metrics Exporter** | `kubectl get svc rec-prom -n redis-enterprise` | Exists | Not found |
| **Cloud Monitoring** | Check GCP Console | Enabled | Disabled |
| **Logging** | `kubectl logs rec-0 -n redis-enterprise` | No errors | Errors |

### **Critical Questions:**

**1. Prometheus Configured?**
- ✅ Prometheus scraping metrics
- ✅ Grafana dashboards
- ❌ No monitoring

**2. Cloud Monitoring Enabled?**
- ✅ GKE metrics in Cloud Monitoring
- ✅ Alerts configured
- ❌ No alerts

**3. Log Aggregation?**
- ✅ Cloud Logging enabled
- ✅ Log-based metrics
- ❌ No centralized logging

### **Commands:**
```bash
# Check Prometheus service
kubectl get svc rec-prom -n redis-enterprise

# Check metrics endpoint
kubectl port-forward svc/rec-prom 8070:8070 -n redis-enterprise
# Then: curl http://localhost:8070/metrics

# Check logs
kubectl logs rec-0 -n redis-enterprise -c redis-enterprise-node
```

---

## 8️⃣ Backup & Disaster Recovery

### **Validation Checklist:**

| Check | Expected | Red Flag |
|-------|----------|----------|
| **Backup Configured** | GCS bucket configured | No backup |
| **Backup Schedule** | Daily or hourly | No schedule |
| **Backup Retention** | 7-30 days | < 7 days |
| **Restore Tested** | Yes | Never tested |

### **Critical Questions:**

**1. Backup Strategy?**
- ✅ Automated backups to GCS
- ✅ Backup schedule (daily/hourly)
- ✅ Retention policy (7-30 days)
- ❌ No backups

**2. Restore Tested?**
- ✅ Restore tested in non-production
- ❌ Never tested (risky)

**3. RPO/RTO?**
- **RPO** (Recovery Point Objective): How much data loss acceptable?
  - Hourly backups = up to 1 hour data loss
- **RTO** (Recovery Time Objective): How fast to restore?
  - Depends on data size

---

## 9️⃣ Operational Readiness

### **Checklist:**

- [ ] **Documentation:** Deployment manifests, runbooks
- [ ] **Access Control:** RBAC configured, least privilege
- [ ] **Secrets Management:** Using Secret Manager or External Secrets
- [ ] **Upgrade Strategy:** Tested in non-production
- [ ] **Incident Response:** Runbook for common issues
- [ ] **Capacity Planning:** Growth projections, scaling plan
- [ ] **Cost Monitoring:** Budget alerts configured

---

## 🔟 Common Issues & Red Flags

### **GKE Cluster:**
- ❌ RAPID release channel in production
- ❌ Single zone deployment
- ❌ Public cluster without authorized networks
- ❌ No Workload Identity

### **Node Pool:**
- ❌ Burstable machine types (e2, t2d)
- ❌ Mixed workloads (no dedicated pool)
- ❌ No autoscaling
- ❌ pd-standard boot disk

### **Storage:**
- ❌ pd-standard (HDD) instead of pd-ssd
- ❌ Deprecated provisioner (kubernetes.io/gce-pd)
- ❌ reclaimPolicy: Delete in production
- ❌ allowVolumeExpansion: false

### **REC:**
- ❌ Even number of nodes (2, 4)
- ❌ Burstable QoS (limits > requests)
- ❌ Volume size < 5x memory
- ❌ Rack awareness not enabled

### **Database:**
- ❌ Replication disabled in production
- ❌ Persistence disabled (cache only)
- ❌ TLS disabled
- ❌ No backups

### **Monitoring:**
- ❌ No Prometheus/Grafana
- ❌ No alerts configured
- ❌ No log aggregation

---

## ✅ Meeting Checklist

Use this during the meeting:

- [ ] Reviewed GKE cluster configuration
- [ ] Reviewed node pool configuration
- [ ] Reviewed storage configuration
- [ ] Reviewed REC configuration
- [ ] Reviewed database configuration
- [ ] Reviewed networking & security
- [ ] Reviewed monitoring setup
- [ ] Reviewed backup strategy
- [ ] Identified red flags
- [ ] Documented action items
- [ ] Scheduled follow-up

---

## 📝 Meeting Notes

**Date:**
**Participants:**
**Cluster:**

**Findings:**
-

**Red Flags:**
-

**Action Items:**
| Task | Owner | Deadline |
|------|-------|----------|
|      |       |          |

**Next Steps:**
-

---

**✅ GKE Review Checklist Complete**

