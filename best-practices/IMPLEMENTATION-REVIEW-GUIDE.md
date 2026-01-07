# Redis Enterprise Implementation Review - Meeting Preparation Guide

**Meeting Type:** Technical Implementation Review
**Product:** Redis Enterprise on Kubernetes
**Platforms Covered:** AWS EKS | Google GKE | Azure AKS | Red Hat OpenShift | On-Premises | Google Distributed Cloud (GDC)
**Audience:** Client Technical Team

---

## 📋 Table of Contents

1. [Pre-Meeting Preparation](#1-pre-meeting-preparation)
2. [Architecture Review Checklist (Common)](#2-architecture-review-checklist-common)
3. [Platform-Specific Validation](#3-platform-specific-validation)
   - [AWS EKS](#aws-eks)
   - [Google GKE](#google-gke)
   - [Azure AKS](#azure-aks)
   - [Red Hat OpenShift](#red-hat-openshift)
   - [Kubernetes On-Premises](#kubernetes-on-premises)
   - [Google Distributed Cloud (GDC)](#google-distributed-cloud-gdc)
4. [Critical Questions to Ask](#4-critical-questions-to-ask)
5. [Common Issues & Solutions](#5-common-issues--solutions)
6. [Best Practices Validation](#6-best-practices-validation)
7. [Security & Compliance Review](#7-security--compliance-review)
8. [Performance & Scalability](#8-performance--scalability)
9. [Operational Readiness](#9-operational-readiness)
10. [Meeting Agenda Template](#10-meeting-agenda-template)

---

## 1. Pre-Meeting Preparation

### 📊 **Information to Request Before Meeting**

Send this list to the client **24-48 hours before** the meeting:

```
Subject: Redis Enterprise on Kubernetes - Implementation Review Preparation

Hi [Client Name],

To make our implementation review meeting as productive as possible, 
please have the following information ready:

KUBERNETES CLUSTER INFORMATION:
- Platform: [ ] AWS EKS  [ ] Google GKE  [ ] Azure AKS  [ ] OpenShift  [ ] On-Premises  [ ] Google Distributed Cloud (GDC)
- Kubernetes version (or distribution: Rancher, Tanzu, etc.)
- Number of nodes and node pool/group configuration
- Node instance types (CPU/memory)
- Regions and availability zones used
- Current cluster utilization

REDIS ENTERPRISE DEPLOYMENT:
- Redis Enterprise Operator version
- Number of REC nodes deployed
- Resource allocation per REC node (CPU/memory)
- Storage class and volume sizes
- Number of databases and their configurations
- Current database utilization (QPS, memory usage)
- Security configuration (TLS, mTLS, RBAC)
- Ingress/Gateway configuration (if any)
- Performance monitoring setup (Prometheus/Grafana)
- Backup and restore configuration
- Cluster configuration (shards, replication, persistence)
- Active-active or active-passive configuration (if applicable)
- LDAP/AD integration (if applicable)

ACCESS (if possible):
- Read-only kubectl access to the cluster
- Access to monitoring dashboards (Prometheus/Grafana/Cloud Monitoring)
- Access to cloud console (for cluster view)

DOCUMENTATION:
- Current deployment manifests (REC, REDB)
- Network architecture diagram
- Backup/restore procedures (if implemented)
- Disaster recovery plan (if exists)

CONCERNS & REQUIREMENTS:
- Any current issues or pain points
- Performance concerns
- Scaling requirements (current and future)
- Compliance/security requirements
- SLA requirements (uptime, RPO, RTO)

Looking forward to our meeting!
```

---

### 🔍 **What to Review Beforehand**

If you receive manifests or access before the meeting:

**Priority 1 - Critical (Must Review):**
- [ ] REC configuration (nodes, resources, storage)
- [ ] Storage class configuration
- [ ] Node pool/group configuration
- [ ] Database configurations (REDB)
- [ ] Resource limits and requests (QoS)

**Priority 2 - Important (Should Review):**
- [ ] Network policies
- [ ] Backup configuration
- [ ] Monitoring setup
- [ ] Security configuration (TLS, secrets)
- [ ] Pod anti-affinity and rack awareness

**Priority 3 - Nice to Have (Good to Review):**
- [ ] Ingress/Gateway configuration
- [ ] External Secrets setup
- [ ] Cloud-specific integrations (IAM, Workload Identity, etc.)
- [ ] GitOps configuration

---

### 📝 **Documents to Bring**

Prepare these materials:

- [ ] This review guide (printed or on tablet)
- [ ] [Best Practices README](README.md)
- [ ] [Validation Runbook](VALIDATION-RUNBOOK.md)
- [ ] Platform-specific guide:
  - [ ] [AWS EKS Guide](../platforms/eks/README.md)
  - [ ] [Google GKE Guide](../platforms/gke/README.md)
  - [ ] [Azure AKS Guide](../platforms/aks/README.md)
  - [ ] [OpenShift Guide](../platforms/openshift/README.md)
  - [ ] On-Premises deployment notes
  - [ ] Google Distributed Cloud (GDC) notes
- [ ] Architecture diagrams (single-region, multi-region)
- [ ] Capacity planning calculator/spreadsheet
- [ ] Common troubleshooting commands cheat sheet

---

## 2. Architecture Review Checklist (Common)

### ✅ **Kubernetes Cluster Configuration (All Platforms)**

**Questions to validate:**

| Item | Question | Expected Answer | Red Flag | Why It Matters |
|------|----------|----------------|----------|----------------|
| **K8s Version** | What Kubernetes version? | 1.27+ (stable) | < 1.23 | Older versions lack critical features and security patches |
| **Node Pools/Groups** | Dedicated pool for Redis? | Yes, separate pool | Mixed workloads | Prevents resource contention and noisy neighbors |
| **Instance Type** | What instance type? | 8+ vCPU, 32+ GB RAM | < 4 vCPU or < 16GB | Redis needs consistent, high-performance compute |
| **Nodes per Zone** | Nodes per AZ? | >= 1 per zone | All in one zone | Single zone = single point of failure |
| **Availability Zones** | How many AZs? | 3 zones | 1 zone | Multi-AZ survives zone failures |
| **Autoscaling** | Node autoscaling enabled? | Yes, with min/max | No autoscaling | Allows dynamic scaling for growth |

**Why review these items:**

**Node Pools/Groups (Dedicated vs Mixed):**
- ✅ **Dedicated:** Predictable performance, easier capacity planning, can use taints/tolerations
- ❌ **Mixed:** Resource contention, unpredictable performance, harder to troubleshoot

**Instance Types:**
- **Why it matters:** Redis is memory-intensive and CPU-sensitive
- **Small instances (< 4 vCPU):** Poor performance, frequent CPU throttling
- **Medium instances (4-8 vCPU):** Acceptable for dev/test
- **Large instances (8+ vCPU):** Recommended for production

**Availability Zones:**
- **1 AZ:** Zone failure = complete outage
- **2 AZs:** Can survive 1 zone failure, but no quorum if split
- **3 AZs:** Can survive 1 zone failure with quorum maintained (recommended)

**Commands to run during meeting:**

```bash
# Get cluster info (platform-specific - see section 3)

# Get nodes
kubectl get nodes -o wide

# Check node labels (zones)
kubectl get nodes -o custom-columns="NODE:metadata.name,ZONE:metadata.labels.topology\.kubernetes\.io/zone,INSTANCE:metadata.labels.node\.kubernetes\.io/instance-type"

# Check node resources
kubectl top nodes

# Check node pools/groups (platform-specific - see section 3)
```

---

### ✅ **Redis Enterprise Cluster (REC) Configuration (All Platforms)**

**Critical validations:**

| Item | Question | Expected Answer | Red Flag | Why It Matters |
|------|----------|----------------|----------|----------------|
| **Number of Nodes** | How many REC nodes? | 3 or 5 (odd number) | 2 or even number | Even numbers can't maintain quorum during failures |
| **CPU per Node** | CPU allocation? | 4000m-8000m | < 2000m | Insufficient CPU causes slow operations and timeouts |
| **Memory per Node** | Memory allocation? | 15Gi-30Gi | < 8Gi | Insufficient memory limits database capacity |
| **Limits = Requests** | Are limits equal to requests? | Yes (Guaranteed QoS) | No (Burstable QoS) | Burstable QoS = pods can be evicted under pressure |
| **Storage Class** | Which storage class? | Platform-specific (see section 3) | Generic/default | Wrong storage class = poor performance or failures |
| **Volume Size** | PVC size per node? | 5x memory (auto or manual) | < 5x memory | Insufficient storage causes database failures |
| **Rack Awareness** | Is rack awareness enabled? | Yes (topology.kubernetes.io/zone) | No | Without rack awareness, all replicas could be in same zone |
| **Anti-Affinity** | Pod anti-affinity configured? | Yes (default) | Disabled | Multiple pods on same node = single point of failure |

**Why review these items:**

**Number of Nodes (Odd vs Even):**
- **Why odd numbers:** Quorum-based consensus requires majority
- **3 nodes:** Can survive 1 node failure (2/3 quorum)
- **5 nodes:** Can survive 2 node failures (3/5 quorum)
- **2 nodes:** Cannot survive any failure (no quorum)
- **4 nodes:** Same fault tolerance as 3 nodes (wastes resources)

**Limits = Requests (QoS Classes):**
- **Guaranteed QoS (limits = requests):**
  - ✅ Pod is NEVER evicted due to resource pressure
  - ✅ Gets dedicated CPU and memory
  - ✅ Predictable performance
  - **Use for:** Production Redis Enterprise

- **Burstable QoS (limits > requests):**
  - ⚠️ Pod CAN be evicted if node is under pressure
  - ⚠️ Shares CPU with other pods
  - ⚠️ Unpredictable performance
  - **Use for:** Dev/test only

- **Best Effort QoS (no limits/requests):**
  - ❌ Pod is evicted FIRST under pressure
  - ❌ No resource guarantees
  - ❌ Highly unpredictable
  - **Use for:** Never use for Redis

**Volume Size (5x Memory Rule):**
- **Why 5x:** Redis Enterprise needs space for:
  - RDB snapshots (1x memory)
  - AOF files (1x memory)
  - Temporary files during operations (1x memory)
  - OS and overhead (1x memory)
  - Buffer for growth (1x memory)
- **Example:** 15Gi memory → 75Gi volume
- **Less than 5x:** Risk of disk full errors during snapshots

**Rack Awareness:**
- **Without rack awareness:**
  - Master and replica could be in same zone
  - Zone failure = data loss

- **With rack awareness:**
  - Master and replica guaranteed in different zones
  - Zone failure = automatic failover, no data loss

**Commands to run:**

```bash
# Get REC configuration
kubectl get rec -n redis-enterprise -o yaml

# Quick validation
echo "Nodes: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}')"
echo "CPU: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.cpu}')"
echo "Memory: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}')"
echo "Storage Class: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.persistentSpec.storageClassName}')"
echo "Rack Awareness: $(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.rackAwarenessNodeLabel}')"

# Check actual pods
kubectl get pods -n redis-enterprise -l app=redis-enterprise -o wide

# Verify QoS
kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.status.qosClass}'
echo ""

# Check PVCs
kubectl get pvc -n redis-enterprise -o custom-columns="NAME:metadata.name,SIZE:spec.resources.requests.storage,STORAGECLASS:spec.storageClassName,STATUS:status.phase"

# Verify pod distribution across zones
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:metadata.name,NODE:spec.nodeName,ZONE:spec.nodeSelector.topology\.kubernetes\.io/zone"
```

---

## 3. Platform-Specific Validation

### AWS EKS

#### ✅ **EKS Cluster Configuration**

**EKS-specific checks:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **EKS Version** | `aws eks describe-cluster --name <cluster> --query cluster.version` | "1.27" or higher | Older versions lack features and security patches |
| **Node Groups** | `aws eks list-nodegroups --cluster-name <cluster>` | Dedicated group for Redis | Isolation and predictable performance |
| **Instance Type** | `aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <group> --query nodegroup.instanceTypes` | m6i.2xlarge or larger | Consistent performance (avoid burstable t3) |
| **AMI Type** | `aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <group> --query nodegroup.amiType` | AL2_x86_64 or BOTTLEROCKET_x86_64 | Optimized for containers |
| **Subnets** | `aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <group> --query nodegroup.subnets` | 3 subnets in different AZs | Multi-AZ deployment |

**Why these matter:**

**Instance Types (m6i vs t3):**
- **m6i/m5/c6i (General Purpose/Compute Optimized):**
  - ✅ Consistent CPU performance
  - ✅ No CPU credits
  - ✅ Predictable latency
  - **Use for:** Production Redis

- **t3/t2 (Burstable):**
  - ❌ CPU credits system
  - ❌ Performance degrades when credits exhausted
  - ❌ Unpredictable latency
  - **Use for:** Dev/test only

**AMI Types:**
- **AL2_x86_64 (Amazon Linux 2):** Standard, well-tested
- **BOTTLEROCKET_x86_64:** Minimal OS, faster boot, more secure
- **AL2_ARM_64:** ARM-based (Graviton), cost-effective but ensure compatibility

**Commands to run:**

```bash
# Get cluster info
aws eks describe-cluster --name <cluster-name> --region <region>

# List node groups
aws eks list-nodegroups --cluster-name <cluster-name> --region <region>

# Get node group details
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --region <region>

# Check if using EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check storage classes
kubectl get storageclass
```

#### ✅ **EKS Storage Configuration**

**EBS-specific validation:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **CSI Driver** | `kubectl get pods -n kube-system \| grep ebs-csi` | Running pods | Required for EBS volumes |
| **Storage Class** | `kubectl get sc` | gp3 (recommended) | gp3 is faster and cheaper than gp2 |
| **Provisioner** | `kubectl get sc gp3 -o jsonpath='{.provisioner}'` | `ebs.csi.aws.com` | Old provisioner (kubernetes.io/aws-ebs) is deprecated |
| **Volume Type** | `kubectl get sc gp3 -o jsonpath='{.parameters.type}'` | gp3 | gp3 offers better performance than gp2 |
| **IOPS** | `kubectl get sc gp3 -o jsonpath='{.parameters.iops}'` | 3000-16000 | Higher IOPS = better performance |
| **Throughput** | `kubectl get sc gp3 -o jsonpath='{.parameters.throughput}'` | 125-1000 | Higher throughput = better performance |

**Storage Class Comparison (EBS):**

| Type | IOPS | Throughput | Cost | Use Case |
|------|------|------------|------|----------|
| **gp3** | 3,000-16,000 (configurable) | 125-1,000 MB/s | $ | **Recommended for production** |
| **gp2** | 3 IOPS/GB (max 16,000) | 250 MB/s | $$ | Legacy, use gp3 instead |
| **io2** | Up to 64,000 | 1,000 MB/s | $$$$ | High-performance (rarely needed) |
| **st1** | 500 | 500 MB/s | $ | HDD, NOT suitable for Redis |

**Why gp3 over gp2:**
- ✅ 20% cheaper
- ✅ Configurable IOPS and throughput (independent of size)
- ✅ Better baseline performance (3,000 IOPS vs gp2's 100-16,000)

**Questions to ask:**

- ✅ **Are you using gp3 or gp2?**
  - If gp2: Recommend migrating to gp3 (cost savings + performance)

- ✅ **Are EBS volumes in the same AZ as nodes?**
  - EBS is AZ-specific (not regional)
  - Volume must be in same AZ as pod

- ✅ **Do you have EBS volume snapshots configured?**
  - Snapshots provide additional backup layer

**Red flags:**

- ❌ Using `kubernetes.io/aws-ebs` provisioner (deprecated)
- ❌ Using gp2 instead of gp3 (wasting money)
- ❌ Using st1 or sc1 (HDD-based, too slow)
- ❌ Using `allowVolumeExpansion: false`

#### ✅ **EKS IAM & Security**

**IRSA (IAM Roles for Service Accounts):**

| Check | Question | Expected Answer | Why It Matters |
|-------|----------|----------------|----------------|
| **IRSA Enabled** | Is IRSA enabled on cluster? | Yes | Best practice for AWS authentication |
| **Service Account** | Is KSA annotated with IAM role? | Yes | Allows pods to assume IAM role |
| **IAM Permissions** | Does IAM role have required permissions? | Yes (S3, Secrets Manager) | Required for backups and secrets |

**IRSA vs IAM Instance Profiles:**

| Method | Security | Granularity | Recommended |
|--------|----------|-------------|-------------|
| **IRSA** | ✅ High (pod-level) | Per service account | ✅ Yes |
| **Instance Profile** | ⚠️ Medium (node-level) | All pods on node | ❌ No |

**Why IRSA is better:**
- ✅ Pod-level permissions (least privilege)
- ✅ No long-lived credentials
- ✅ Automatic credential rotation
- ✅ Audit trail per service account

**Commands to validate:**

```bash
# Check if IRSA is enabled
aws eks describe-cluster --name <cluster> --region <region> \
  --query "cluster.identity.oidc.issuer"

# Check service account annotation
kubectl get sa -n redis-enterprise -o yaml | grep eks.amazonaws.com/role-arn

# Verify IAM role
aws iam get-role --role-name <role-name>

# Check IAM role policies
aws iam list-attached-role-policies --role-name <role-name>
```

---

### Google GKE

#### ✅ **GKE Cluster Configuration**

**GKE-specific checks:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **GKE Version** | `gcloud container clusters describe <cluster> --region <region> --format="value(currentMasterVersion)"` | 1.27+ | Older versions lack features |
| **Release Channel** | `gcloud container clusters describe <cluster> --region <region> --format="value(releaseChannel.channel)"` | REGULAR or STABLE | RAPID is too unstable for production |
| **Cluster Mode** | `gcloud container clusters describe <cluster> --region <region> --format="value(autopilot.enabled)"` | False (Standard) or True (Autopilot) | Different management models |
| **Node Pools** | `gcloud container node-pools list --cluster <cluster> --region <region>` | Dedicated pool for Redis | Isolation and predictable performance |
| **Machine Type** | `gcloud container node-pools describe <pool> --cluster <cluster> --region <region> --format="value(config.machineType)"` | n2-standard-8 or larger | Consistent performance |

**Why these matter:**

**Release Channels:**
- **RAPID:** New features quickly, but less stable (not for production)
- **REGULAR:** Balanced updates, good for most workloads ✅
- **STABLE:** Slower updates, maximum stability ✅
- **Recommendation:** REGULAR or STABLE for production

**Autopilot vs Standard:**

| Feature                 | Autopilot                  | Standard                           | Recommendation 
|---------                |-----------                 |----------                          |----------------
| **Node Management**     | Fully managed by Google    | Customer managed                   | Autopilot = less ops overhead 
| **Node Pools**          | Not configurable           | Fully configurable                 | Standard = more control 
| **Resource Limits**     | Enforced by Google         | Customer defined                   | Autopilot = must fit within limits 
| **Storage Classes**     | Limited (premium-rwo)      | Full control (pd-ssd, pd-balanced) | Standard = more options 
| **Cost**                | Pay per pod | Pay per node | Autopilot = potentially cheaper.   |
| **nodeSelector/Taints** | Not supported | Supported  | Standard = better isolation        |

**When to use Autopilot:**
- ✅ Want minimal operational overhead
- ✅ Workloads fit within Google's limits
- ✅ Don't need custom node configurations

**When to use Standard:**
- ✅ Need dedicated node pools
- ✅ Need custom node configurations
- ✅ Need specific storage classes
- ✅ Need nodeSelector/taints for isolation

**Commands to run:**

```bash
# Get cluster info
gcloud container clusters describe <cluster-name> --region <region>

# Check if Autopilot
gcloud container clusters describe <cluster-name> --region <region> \
  --format="value(autopilot.enabled)"

# List node pools (Standard only)
gcloud container node-pools list --cluster <cluster-name> --region <region>

# Get node pool details (Standard only)
gcloud container node-pools describe <pool-name> \
  --cluster <cluster-name> --region <region>

# Check if using GCE PD CSI driver
kubectl get pods -n kube-system | grep csi-gce-pd

# Check storage classes
kubectl get storageclass
```

#### ✅ **GKE Storage Configuration**

**GCE Persistent Disk validation:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **CSI Driver** | `kubectl get pods -n kube-system \| grep csi-gce-pd` | Running pods | Required for GCE PD volumes |
| **Storage Class** | `kubectl get sc` | pd-ssd or pd-balanced | pd-ssd for production |
| **Provisioner** | `kubectl get sc <name> -o jsonpath='{.provisioner}'` | `pd.csi.storage.gke.io` | Old provisioner is deprecated |
| **Volume Type** | `kubectl get sc <name> -o jsonpath='{.parameters.type}'` | pd-ssd or pd-balanced | pd-standard (HDD) is too slow |

**Storage Class Comparison (GCE PD):**

| Type | IOPS | Throughput | Cost | Use Case |
|------|------|------------|------|----------|
| **pd-ssd** | Up to 30,000 | Up to 1,200 MB/s | $$$ | **Production (recommended)** |
| **pd-balanced** | Up to 6,000 | Up to 240 MB/s | $$ | Dev/test or cost-sensitive |
| **pd-standard** | Up to 7,500 | Up to 1,200 MB/s | $ | HDD, NOT suitable for Redis |
| **pd-extreme** | Up to 120,000 | Up to 2,400 MB/s | $$$$ | High-performance (rarely needed) |

**Why pd-ssd over pd-balanced:**
- ✅ 5x higher IOPS (30,000 vs 6,000)
- ✅ 5x higher throughput (1,200 MB/s vs 240 MB/s)
- ✅ Lower latency
- ⚠️ Higher cost (but worth it for production)

**Autopilot Storage:**
- **Available:** premium-rwo (SSD-based)
- **Not available:** pd-balanced, pd-standard
- **Recommendation:** Use premium-rwo (equivalent to pd-ssd)

**Questions to ask:**

- ✅ **Are you using pd-ssd or pd-balanced?**
  - Production: pd-ssd
  - Dev/test: pd-balanced

- ✅ **Are PVCs in the same zone as nodes?**
  - GCE PD is zonal (not regional)
  - PVC must be in same zone as pod

**Red flags:**

- ❌ Using `standard` storage class (deprecated, HDD-based)
- ❌ Using `kubernetes.io/gce-pd` provisioner (deprecated)
- ❌ Using `allowVolumeExpansion: false`
- ❌ Using `reclaimPolicy: Delete` in production

#### ✅ **GKE Workload Identity**

**Workload Identity (GKE's version of IRSA):**

| Check | Question | Expected Answer | Why It Matters |
|-------|----------|----------------|----------------|
| **Workload Identity** | Is Workload Identity enabled? | Yes | Best practice for GCP authentication |
| **Service Account** | Is KSA bound to GSA? | Yes | Allows pods to use GCP services |
| **IAM Permissions** | Does GSA have required permissions? | Yes (Secret Manager, GCS) | Required for secrets and backups |

**Workload Identity vs Service Account Keys:**

| Method | Security | Granularity | Recommended |
|--------|----------|-------------|-------------|
| **Workload Identity** | ✅ High (pod-level) | Per service account | ✅ Yes |
| **Service Account Keys** | ❌ Low (static credentials) | Manual rotation | ❌ No |

**Why Workload Identity is better:**
- ✅ No long-lived credentials
- ✅ Automatic credential rotation
- ✅ Pod-level permissions
- ✅ Audit trail per service account

**Commands to validate:**

```bash
# Check if Workload Identity is enabled
gcloud container clusters describe <cluster> --region <region> \
  --format="value(workloadIdentityConfig.workloadPool)"

# Expected: <project-id>.svc.id.goog

# Check service account annotation
kubectl get sa -n redis-enterprise -o yaml | grep iam.gke.io/gcp-service-account

# Verify GSA permissions
gcloud projects get-iam-policy <project-id> \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:<gsa-email>"
```

---

### Azure AKS

#### ✅ **AKS Cluster Configuration**

**AKS-specific checks:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **AKS Version** | `az aks show -n <cluster> -g <rg> --query kubernetesVersion` | "1.27" or higher | Older versions lack features |
| **Node Pools** | `az aks nodepool list -g <rg> --cluster-name <cluster>` | Dedicated pool for Redis | Isolation and predictable performance |
| **VM Size** | `az aks nodepool show -g <rg> --cluster-name <cluster> -n <pool> --query vmSize` | Standard_D8s_v5 or larger | Consistent performance |
| **Availability Zones** | `az aks nodepool show -g <rg> --cluster-name <cluster> -n <pool> --query availabilityZones` | [1,2,3] | Multi-AZ deployment |

**Why these matter:**

**VM Sizes (D-series vs B-series):**
- **D-series (General Purpose):**
  - ✅ Consistent CPU performance
  - ✅ Good memory-to-CPU ratio
  - ✅ Predictable latency
  - **Use for:** Production Redis

- **B-series (Burstable):**
  - ❌ CPU credits system
  - ❌ Performance degrades when credits exhausted
  - ❌ Unpredictable latency
  - **Use for:** Dev/test only

**Recommended VM Sizes:**
- **Standard_D8s_v5:** 8 vCPU, 32 GB RAM (good for most workloads)
- **Standard_D16s_v5:** 16 vCPU, 64 GB RAM (high-performance)
- **Standard_E8s_v5:** 8 vCPU, 64 GB RAM (memory-optimized)

**Commands to run:**

```bash
# Get cluster info
az aks show --name <cluster-name> --resource-group <resource-group>

# List node pools
az aks nodepool list --cluster-name <cluster-name> --resource-group <resource-group>

# Get node pool details
az aks nodepool show \
  --cluster-name <cluster-name> \
  --resource-group <resource-group> \
  --name <nodepool-name>

# Check if using Azure Disk CSI driver
kubectl get pods -n kube-system | grep csi-azuredisk

# Check storage classes
kubectl get storageclass
```

#### ✅ **AKS Storage Configuration**

**Azure Disk validation:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **CSI Driver** | `kubectl get pods -n kube-system \| grep csi-azuredisk` | Running pods | Required for Azure Disk volumes |
| **Storage Class** | `kubectl get sc` | managed-premium or managed-csi-premium | Premium SSD for production |
| **Provisioner** | `kubectl get sc <name> -o jsonpath='{.provisioner}'` | `disk.csi.azure.com` | Old provisioner is deprecated |
| **SKU Name** | `kubectl get sc <name> -o jsonpath='{.parameters.skuName}'` | Premium_LRS or Premium_ZRS | Premium for production |

**Storage Class Comparison (Azure Disk):**

| Type | IOPS | Throughput | Cost | Use Case |
|------|------|------------|------|----------|
| **Premium_LRS** | Up to 20,000 | Up to 900 MB/s | $$$ | **Production (recommended)** |
| **Premium_ZRS** | Up to 20,000 | Up to 900 MB/s | $$$$ | Zone-redundant (high availability) |
| **StandardSSD_LRS** | Up to 6,000 | Up to 750 MB/s | $$ | Dev/test |
| **Standard_LRS** | Up to 2,000 | Up to 500 MB/s | $ | HDD, NOT suitable for Redis |

**LRS vs ZRS:**
- **LRS (Locally Redundant Storage):**
  - 3 copies within single zone
  - Lower cost
  - **Use for:** Most workloads (Redis has its own replication)

- **ZRS (Zone Redundant Storage):**
  - 3 copies across 3 zones
  - Higher cost
  - **Use for:** Critical workloads requiring zone-level redundancy

**Why Premium_LRS over StandardSSD_LRS:**
- ✅ 3x higher IOPS (20,000 vs 6,000)
- ✅ Higher throughput (900 MB/s vs 750 MB/s)
- ✅ Lower latency
- ⚠️ Higher cost (but worth it for production)

**Questions to ask:**

- ✅ **Are you using Premium or Standard SSD?**
  - Production: Premium_LRS
  - Dev/test: StandardSSD_LRS

- ✅ **Do you need ZRS (zone-redundant storage)?**
  - Usually not needed (Redis has replication)
  - ZRS adds cost without much benefit

**Red flags:**

- ❌ Using `kubernetes.io/azure-disk` provisioner (deprecated)
- ❌ Using Standard_LRS (HDD-based, too slow)
- ❌ Using `allowVolumeExpansion: false`

#### ✅ **AKS Managed Identity**

**Azure Managed Identity (AKS's version of IRSA):**

| Check | Question | Expected Answer | Why It Matters |
|-------|----------|----------------|----------------|
| **Managed Identity** | Is managed identity enabled? | Yes | Best practice for Azure authentication |
| **Workload Identity** | Is workload identity enabled? | Yes (AKS 1.25+) | Pod-level identity |
| **Service Account** | Is KSA federated with managed identity? | Yes | Allows pods to use Azure services |

**Managed Identity vs Service Principal:**

| Method | Security | Granularity | Recommended |
|--------|----------|-------------|-------------|
| **Workload Identity** | ✅ High (pod-level) | Per service account | ✅ Yes (AKS 1.25+) |
| **Pod Identity** | ✅ High (pod-level) | Per pod | ⚠️ Deprecated (use Workload Identity) |
| **Service Principal** | ⚠️ Medium (static credentials) | Manual rotation | ❌ No |

**Commands to validate:**

```bash
# Check if managed identity is enabled
az aks show -n <cluster> -g <rg> --query identity.type

# Check if workload identity is enabled
az aks show -n <cluster> -g <rg> --query oidcIssuerProfile.enabled

# Check service account annotation
kubectl get sa -n redis-enterprise -o yaml | grep azure.workload.identity/client-id
```

---

### Red Hat OpenShift

#### ✅ **OpenShift Cluster Configuration**

**OpenShift-specific checks:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **OpenShift Version** | `oc version` | 4.12+ | Older versions lack features |
| **Machine Pools** | `oc get machineset -n openshift-machine-api` | Dedicated pool for Redis | Isolation and predictable performance |
| **Instance Type** | `oc get machineset <name> -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.instanceType}'` | Platform-specific (see above) | Consistent performance |

**Why these matter:**

**OpenShift vs Vanilla Kubernetes:**
- **Security:** OpenShift has stricter security by default (SCCs)
- **Operator Lifecycle Manager (OLM):** Built-in operator management
- **Routes:** Built-in ingress (alternative to Ingress/Gateway API)
- **Registry:** Built-in container registry

**Security Context Constraints (SCCs):**
- OpenShift uses SCCs instead of Pod Security Standards
- Redis Enterprise Operator requires specific SCC
- **Important:** Operator must be installed via OLM or with proper SCC

**Commands to run:**

```bash
# Get cluster version
oc version

# List machine sets
oc get machineset -n openshift-machine-api

# Get machine set details
oc describe machineset <machineset-name> -n openshift-machine-api

# Check storage classes
oc get storageclass

# Check if Redis Enterprise Operator is installed via OLM
oc get csv -n redis-enterprise | grep redis-enterprise-operator
```

#### ✅ **OpenShift Storage Configuration**

**Storage depends on underlying platform:**

| Platform | Storage Class | Provisioner | Use Case |
|----------|---------------|-------------|----------|
| **AWS (ROSA)** | gp3-csi | ebs.csi.aws.com | Same as EKS |
| **Azure (ARO)** | managed-csi-premium | disk.csi.azure.com | Same as AKS |
| **GCP** | pd-ssd | pd.csi.storage.gke.io | Same as GKE |
| **VMware** | thin | kubernetes.io/vsphere-volume | vSphere storage |
| **Bare Metal** | local-storage or Ceph/ODF | Various | Depends on setup |

**OpenShift Data Foundation (ODF):**
- Formerly OpenShift Container Storage (OCS)
- Based on Ceph
- Provides block, file, and object storage
- **Can be used for Redis, but block storage is preferred**

**Questions to ask:**

- ✅ **What is the underlying platform?** (AWS/Azure/GCP/VMware/Bare Metal)
- ✅ **Are you using ODF or platform-native storage?**
  - Platform-native (EBS/Azure Disk/GCE PD) is usually better
  - ODF adds complexity

**Commands to validate:**

```bash
# Check storage classes
oc get storageclass

# Check if using ODF
oc get pods -n openshift-storage

# Check PVCs
oc get pvc -n redis-enterprise
```

#### ✅ **OpenShift Operator Lifecycle Manager (OLM)**

**OLM-specific validation:**

| Check | Command | Expected Result | Why It Matters |
|-------|---------|----------------|----------------|
| **Operator Installed via OLM** | `oc get csv -n redis-enterprise` | redis-enterprise-operator | OLM manages upgrades |
| **Approval Strategy** | `oc get subscription -n redis-enterprise -o jsonpath='{.items[0].spec.installPlanApproval}'` | Manual | Automatic upgrades can break cluster |
| **Update Channel** | `oc get subscription -n redis-enterprise -o jsonpath='{.items[0].spec.channel}'` | stable | Stable channel for production |

**Why Manual approval is critical:**

- **Automatic upgrades:**
  - ❌ Can upgrade operator without warning
  - ❌ May introduce breaking changes
  - ❌ Can cause cluster downtime

- **Manual upgrades:**
  - ✅ Control when upgrades happen
  - ✅ Test in non-production first
  - ✅ Plan maintenance windows

**Commands to validate:**

```bash
# Check if operator is installed via OLM
oc get csv -n redis-enterprise

# Check subscription
oc get subscription -n redis-enterprise

# Check install plan approval
oc get subscription -n redis-enterprise -o yaml | grep installPlanApproval

# Expected: Manual (NOT Automatic)
```

**Red flags:**

- ❌ `installPlanApproval: Automatic` (dangerous for production)
- ❌ Operator not installed via OLM (missing SCC configuration)

---

### Kubernetes On-Premises

#### ✅ **On-Premises Cluster Configuration**

**On-Premises-specific checks:**

| Check | Question | Expected Answer | Why It Matters |
|-------|----------|----------------|----------------|
| **K8s Distribution** | Which distribution? | Rancher, Tanzu, Canonical, Upstream | Different distributions have different features |
| **Infrastructure** | Bare metal or VMs? | VMs (VMware, KVM, Hyper-V) or Bare metal | Affects storage and networking options |
| **Node Provisioning** | How are nodes provisioned? | Automated (Terraform, Ansible) or Manual | Automation ensures consistency |
| **Load Balancer** | What LB solution? | MetalLB, HAProxy, F5, hardware LB | Required for LoadBalancer services |
| **Ingress** | What ingress controller? | NGINX, Traefik, HAProxy | Required for external access |

**Why these matter:**

**Kubernetes Distributions:**

| Distribution | Characteristics | Considerations |
|--------------|----------------|----------------|
| **Rancher (RKE/RKE2)** | Easy to deploy, good UI, multi-cluster management | Check Rancher version, storage options |
| **VMware Tanzu** | Enterprise support, integrated with vSphere | Check NSX-T integration, storage policies |
| **Canonical (MicroK8s/Charmed K8s)** | Ubuntu-based, snap packages | Check storage add-ons, HA configuration |
| **Upstream (kubeadm)** | Vanilla Kubernetes, full control | More manual configuration required |
| **K3s** | Lightweight, edge-focused | Limited for production (use RKE2 instead) |

**Infrastructure (VMs vs Bare Metal):**

| Type | Pros | Cons | Recommendation |
|------|------|------|----------------|
| **VMs (VMware/KVM)** | ✅ Easier to manage<br>✅ Snapshots<br>✅ Live migration | ⚠️ Hypervisor overhead<br>⚠️ Storage complexity | Recommended for most on-prem |
| **Bare Metal** | ✅ Maximum performance<br>✅ No overhead | ⚠️ Harder to manage<br>⚠️ No live migration | Only for high-performance needs |

**Load Balancer Solutions:**

| Solution | Type | Pros | Cons |
|----------|------|------|------|
| **MetalLB** | Software (L2/BGP) | ✅ Free<br>✅ Easy to deploy | ⚠️ Limited features<br>⚠️ L2 mode has limitations |
| **HAProxy** | Software (L4/L7) | ✅ Mature<br>✅ Feature-rich | ⚠️ Requires external setup |
| **F5/Citrix** | Hardware | ✅ Enterprise features<br>✅ High performance | ⚠️ Expensive<br>⚠️ Complex |

**Questions to ask:**

- ✅ **Which Kubernetes distribution are you using?**
  - Version and update strategy

- ✅ **Is this VMware vSphere or other hypervisor?**
  - vSphere: Check vSphere CSI driver
  - KVM: Check storage options (Ceph, NFS, local)

- ✅ **How do you handle load balancing?**
  - MetalLB, hardware LB, NodePort

- ✅ **What is your storage backend?**
  - See storage section below

**Commands to run:**

```bash
# Get cluster info
kubectl version
kubectl get nodes -o wide

# Check distribution-specific components
# Rancher:
kubectl get pods -n cattle-system

# Tanzu:
kubectl get tanzukubernetescluster

# Check load balancer
kubectl get svc -A | grep LoadBalancer

# Check ingress controller
kubectl get pods -n ingress-nginx  # or other namespace
```

---

#### ✅ **On-Premises Storage Configuration**

**Storage is the most critical aspect of on-premises deployments.**

**Storage Options:**

| Storage Type | Provisioner | Pros | Cons | Use Case |
|--------------|-------------|------|------|----------|
| **VMware vSAN/VMFS** | csi.vsphere.vmware.com | ✅ Integrated with vSphere<br>✅ Enterprise support | ⚠️ VMware-only<br>⚠️ Licensing cost | VMware environments |
| **Ceph (Rook)** | rook-ceph.rbd.csi.ceph.com | ✅ Open source<br>✅ Highly available<br>✅ Block, file, object | ⚠️ Complex to manage<br>⚠️ Requires dedicated nodes | Large on-prem deployments |
| **Portworx** | pxd.portworx.com | ✅ Enterprise features<br>✅ Multi-cloud support<br>✅ DR features | ⚠️ Licensing cost<br>⚠️ Complexity | Enterprise on-prem |
| **OpenEBS** | openebs.io/local | ✅ Open source<br>✅ Multiple engines | ⚠️ Less mature<br>⚠️ Performance varies | Dev/test or specific use cases |
| **Local Storage** | kubernetes.io/no-provisioner | ✅ Simple<br>✅ High performance | ❌ No replication<br>❌ Node-bound | NOT recommended for Redis |
| **NFS** | nfs.csi.k8s.io | ✅ Simple<br>✅ Shared storage | ❌ NOT suitable for Redis<br>❌ Locking issues | Never use for Redis |

**Recommended Storage for Redis Enterprise:**

1. **VMware vSphere:** vSphere CSI driver (vSAN or VMFS)
2. **Bare Metal/KVM:** Ceph (via Rook) or Portworx
3. **Small deployments:** Local SSDs with proper backup strategy

**Why these matter:**

**vSphere CSI Driver:**
- ✅ Native integration with vSphere
- ✅ Supports volume expansion, snapshots
- ✅ Works with vSAN (distributed) or VMFS (local)
- **Requirement:** vSphere 6.7U3+ and vSphere CSI driver installed

**Ceph (Rook):**
- ✅ Distributed storage (survives node failures)
- ✅ Block storage (RBD) suitable for Redis
- ✅ Open source (no licensing)
- ⚠️ Requires at least 3 nodes with dedicated disks
- ⚠️ Complex to troubleshoot

**Portworx:**
- ✅ Enterprise-grade features (DR, encryption, QoS)
- ✅ Easier to manage than Ceph
- ✅ Good support
- ⚠️ Licensing cost
- ⚠️ Requires dedicated disks

**Questions to ask:**

- ✅ **What storage backend are you using?**
  - vSphere, Ceph, Portworx, local, NFS

- ✅ **If vSphere, are you using vSAN or VMFS?**
  - vSAN: Distributed (recommended)
  - VMFS: Local to ESXi host (less resilient)

- ✅ **If Ceph, how many OSD nodes?**
  - Minimum 3 for redundancy

- ✅ **What is the underlying disk type?**
  - SSD (recommended)
  - NVMe (best performance)
  - HDD (NOT recommended for Redis)

**Commands to validate:**

```bash
# Check storage classes
kubectl get storageclass

# Check provisioner
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# VMware vSphere:
kubectl get pods -n vmware-system-csi

# Ceph (Rook):
kubectl get pods -n rook-ceph
kubectl get cephcluster -n rook-ceph

# Portworx:
kubectl get pods -n kube-system | grep portworx

# Check PVCs
kubectl get pvc -n redis-enterprise
```

**Red flags:**

- ❌ Using NFS for Redis (causes locking issues)
- ❌ Using local storage without backup strategy
- ❌ Using HDD instead of SSD
- ❌ Ceph cluster with < 3 OSD nodes
- ❌ No volume expansion support

**Quick Decision Matrix - On-Premises Storage:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Infrastructure Type → Recommended Storage                       │
├─────────────────────────────────────────────────────────────────┤
│ VMware vSphere      → vSphere CSI (vSAN or VMFS)               │
│ Bare Metal (3+ nodes) → Ceph (Rook) or Portworx                │
│ Bare Metal (1-2 nodes) → Local SSDs + GCS/S3 backups           │
│ KVM/Proxmox         → Ceph (Rook) or local + backups           │
│ Small/Edge          → Local SSDs + frequent backups            │
└─────────────────────────────────────────────────────────────────┘

Budget Considerations:
├─ Free/Open Source: vSphere CSI (if you have vSphere), Ceph (Rook)
├─ Commercial: Portworx ($$), Pure Storage ($$$$)
└─ Hybrid: Local SSDs + cloud backups (S3/GCS)
```

**Storage Performance Comparison:**

| Storage | Latency | IOPS | Throughput | Complexity | Cost |
|---------|---------|------|------------|------------|------|
| **Local NVMe** | < 100μs | 100K+ | 3+ GB/s | Low | $$ |
| **Local SSD** | < 500μs | 50K+ | 1+ GB/s | Low | $ |
| **vSAN (All-Flash)** | < 1ms | 30K+ | 1+ GB/s | Medium | $$$ |
| **Ceph (SSD)** | 1-3ms | 20K+ | 500 MB/s | High | $ (OSS) |
| **Portworx (SSD)** | 1-2ms | 25K+ | 800 MB/s | Medium | $$$ |
| **NFS** | 5-10ms | 5K | 200 MB/s | Low | ❌ NOT for Redis |

---

#### ✅ **On-Premises Networking**

**Networking challenges in on-premises:**

| Challenge | Solution | Why It Matters |
|-----------|----------|----------------|
| **No cloud load balancer** | MetalLB, HAProxy, hardware LB | Required for LoadBalancer services |
| **No cloud DNS** | External DNS, manual DNS | Required for external access |
| **Firewall rules** | Network policies, firewall config | Security and compliance |
| **IP address management** | IPAM solution or manual | Avoid IP conflicts |

**Load Balancer Options:**

**MetalLB (Most Common):**
```bash
# Check if MetalLB is installed
kubectl get pods -n metallb-system

# Check IP address pool
kubectl get ipaddresspool -n metallb-system

# Check L2Advertisement or BGPAdvertisement
kubectl get l2advertisement -n metallb-system
kubectl get bgpadvertisement -n metallb-system
```

**MetalLB Modes:**
- **L2 Mode:** Simple, works on any network, but has limitations (single node handles traffic)
- **BGP Mode:** More scalable, requires BGP-capable router, better for production

**Questions to ask:**

- ✅ **How do you expose services externally?**
  - LoadBalancer (MetalLB, hardware LB)
  - NodePort (not recommended for production)
  - Ingress (requires ingress controller)

- ✅ **What IP range is allocated for LoadBalancer services?**
  - Must not conflict with existing network

- ✅ **Do you have network policies enabled?**
  - Calico, Cilium, or other CNI

**Red flags:**

- ❌ Using NodePort for production (not scalable)
- ❌ No load balancer solution (can't use LoadBalancer services)
- ❌ IP conflicts with existing network
- ❌ No network policies (security risk)

---

#### ✅ **On-Premises High Availability**

**HA considerations for on-premises:**

| Component | Requirement | Why It Matters |
|-----------|-------------|----------------|
| **Control Plane** | 3+ master nodes | Survives master node failure |
| **Worker Nodes** | 3+ per AZ/rack | Survives worker node failure |
| **Storage** | Replicated (vSAN, Ceph) | Survives storage node failure |
| **Network** | Redundant switches/links | Survives network failure |
| **Power** | Redundant PSUs, UPS | Survives power failure |

**Questions to ask:**

- ✅ **How many master nodes do you have?**
  - 1 master = single point of failure
  - 3 masters = recommended

- ✅ **Are nodes spread across racks/zones?**
  - Physical separation for fault tolerance

- ✅ **Do you have redundant network connectivity?**
  - Multiple switches, bonded NICs

- ✅ **What is your backup power strategy?**
  - UPS, generators

---

### Google Distributed Cloud (GDC)

#### ✅ **GDC Overview**

**Google Distributed Cloud (formerly Anthos on bare metal/VMware):**

| GDC Type | Description | Use Case |
|----------|-------------|----------|
| **GDC Hosted** | Google-managed hardware at customer site | Edge, low-latency, data residency |
| **GDC Virtual** | Customer-managed VMs (VMware, bare metal) | Hybrid cloud, on-prem with Google tools |
| **GDC Edge** | Small footprint, edge locations | Retail, manufacturing, remote sites |

**Why GDC is different from standard on-prem:**
- ✅ Google-managed control plane (GDC Hosted)
- ✅ Integrated with Google Cloud (logging, monitoring)
- ✅ Consistent API with GKE
- ✅ Workload Identity support (federated with Google Cloud)

---

#### ✅ **GDC Cluster Configuration**

**GDC-specific checks:**

| Check | Question | Expected Answer | Why It Matters |
|-------|----------|----------------|----------------|
| **GDC Type** | Hosted, Virtual, or Edge? | Depends on use case | Different management models |
| **GKE Version** | What version? | 1.27+ | Consistent with GKE |
| **Node Pools** | Dedicated pool for Redis? | Yes | Isolation and performance |
| **Connect to Google Cloud** | Is cluster connected? | Yes (for monitoring, logging) | Enables cloud integration |

**Questions to ask:**

- ✅ **Which GDC type are you using?**
  - Hosted: Google manages hardware
  - Virtual: Customer manages infrastructure
  - Edge: Small footprint

- ✅ **Is the cluster connected to Google Cloud?**
  - Enables Cloud Logging, Cloud Monitoring
  - Enables Workload Identity

- ✅ **Are you using Workload Identity?**
  - Federated identity with Google Cloud
  - Access to Secret Manager, GCS

**Commands to run:**

```bash
# Get cluster info
kubectl version
kubectl get nodes -o wide

# Check GDC-specific components
kubectl get pods -n gke-system

# Check if connected to Google Cloud
kubectl get pods -n gke-connect

# Check storage classes
kubectl get storageclass
```

---

#### ✅ **GDC Storage Configuration**

**GDC storage depends on deployment type:**

| GDC Type | Storage Options | Provisioner | Recommendation |
|----------|----------------|-------------|----------------|
| **GDC Hosted** | Local SSDs, vSAN (if VMware) | csi.vsphere.vmware.com or local | Use vSAN if available |
| **GDC Virtual (VMware)** | vSAN, VMFS | csi.vsphere.vmware.com | Use vSphere CSI driver |
| **GDC Virtual (Bare Metal)** | Ceph, Portworx, local | Various | Use Ceph or Portworx |
| **GDC Edge** | Local SSDs | local-static-provisioner | Local storage with backups |

**Why these matter:**

**GDC Hosted:**
- Google provides hardware
- Storage is typically local SSDs or vSAN
- Check with Google for storage options

**GDC Virtual (VMware):**
- Same as on-premises VMware
- Use vSphere CSI driver
- vSAN recommended for HA

**GDC Edge:**
- Small footprint (1-3 nodes)
- Local storage only
- **Critical:** Must have backup strategy (GCS recommended)

**Questions to ask:**

- ✅ **What storage backend are you using?**
  - vSAN, local SSDs, Ceph

- ✅ **If GDC Edge, what is your backup strategy?**
  - Local storage is not replicated
  - Must backup to GCS or other remote storage

- ✅ **Are you using Google Cloud Storage for backups?**
  - Workload Identity makes this easy

**Commands to validate:**

```bash
# Check storage classes
kubectl get storageclass

# Check provisioner
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# Check PVCs
kubectl get pvc -n redis-enterprise
```

---

#### ✅ **GDC Integration with Google Cloud**

**GDC can integrate with Google Cloud services:**

| Service | Use Case | Requirement |
|---------|----------|-------------|
| **Cloud Logging** | Centralized logs | Cluster connected to Google Cloud |
| **Cloud Monitoring** | Metrics and alerting | Cluster connected to Google Cloud |
| **Secret Manager** | Secrets management | Workload Identity configured |
| **Cloud Storage (GCS)** | Backups | Workload Identity configured |

**Workload Identity on GDC:**
- Similar to GKE Workload Identity
- Federates Kubernetes service accounts with Google Cloud service accounts
- Enables access to Google Cloud services without keys

**Questions to ask:**

- ✅ **Is the cluster connected to Google Cloud?**
  - Enables logging, monitoring, Workload Identity

- ✅ **Are you using Workload Identity?**
  - For Secret Manager, GCS backups

- ✅ **Are you using Cloud Logging/Monitoring?**
  - Centralized observability

**Commands to validate:**

```bash
# Check if connected to Google Cloud
kubectl get pods -n gke-connect

# Check Workload Identity configuration
kubectl get sa -n redis-enterprise -o yaml | grep iam.gke.io/gcp-service-account

# Check if using Cloud Logging
kubectl get pods -n gke-system | grep fluentbit
```

**Why this matters:**
- GDC with Google Cloud integration provides best of both worlds
- On-premises deployment with cloud-native tools
- Workload Identity eliminates need for service account keys

---

## 4. Critical Questions to Ask

### 🎯 **Business & Requirements (All Platforms)**

**Start with understanding the "why":**

1. **What is the primary use case for Redis?**
   - Cache (most common)
   - Session store
   - Real-time analytics
   - Message queue (Streams)
   - Primary database
   - **Why it matters:** Different use cases have different requirements (persistence, replication, etc.)

2. **What are your SLA requirements?**
   - Uptime target (99.9%, 99.95%, 99.99%)
   - RPO (Recovery Point Objective) - How much data loss is acceptable?
   - RTO (Recovery Time Objective) - How quickly must service be restored?
   - **Why it matters:** Determines architecture (single-region vs multi-region, backup frequency, etc.)

3. **What is your expected growth?**
   - Current data size
   - Expected data size in 6/12 months
   - Current QPS (queries per second)
   - Expected QPS in 6/12 months
   - **Why it matters:** Determines capacity planning and scaling strategy

4. **What are your compliance requirements?**
   - Data encryption (at rest, in transit)
   - Data residency (must stay in specific region/country)
   - Audit logging
   - Access controls
   - **Why it matters:** Determines security configuration and architecture

---

### 🔧 **Technical Deep Dive (All Platforms)**

**Architecture:**

5. **How many environments do you have?**
   - Dev, staging, production
   - Separate clusters or namespaces?
   - **Why it matters:** Determines isolation strategy and cost

6. **Do you need multi-region deployment?**
   - Active-Active (both regions serve traffic)
   - Active-Passive (DR only)
   - Single region only
   - **Why it matters:** Determines architecture complexity and cost

7. **What is your disaster recovery strategy?**
   - Backups only (restore from backup)
   - Multi-region replication (failover to another region)
   - Both
   - **Why it matters:** Determines RTO/RPO and architecture

**Operations:**

8. **Who manages the Redis cluster?**
   - Platform team
   - Application team
   - Shared responsibility
   - **Why it matters:** Determines training needs and operational procedures

9. **How do you deploy changes?**
   - GitOps (ArgoCD, Flux)
   - Manual kubectl/oc
   - CI/CD pipeline
   - **Why it matters:** Determines automation and consistency

10. **What is your monitoring strategy?**
    - Prometheus + Grafana
    - Cloud-native monitoring (CloudWatch/Cloud Monitoring/Azure Monitor)
    - Third-party (Datadog, New Relic)
    - **Why it matters:** Determines observability setup

**Security:**

11. **How do you manage secrets?**
    - Kubernetes Secrets (not recommended for production)
    - External Secrets Operator + Cloud Secret Manager
    - HashiCorp Vault
    - **Why it matters:** Determines security posture

12. **Do you require TLS for all connections?**
    - Client-to-Redis
    - Redis-to-Redis (replication)
    - Both
    - **Why it matters:** Determines network security configuration

13. **What authentication method do you use?**
    - Password only
    - mTLS
    - Both
    - **Why it matters:** Determines access control configuration

---

### ⚠️ **Pain Points & Concerns (All Platforms)**

**Ask open-ended questions:**

14. **What challenges have you faced so far?**
    - Listen carefully - this reveals real issues
    - Common answers: Performance, complexity, cost, lack of expertise

15. **What keeps you up at night about this deployment?**
    - Data loss
    - Performance degradation
    - Cost overruns
    - Operational complexity
    - **Why it matters:** Reveals priorities and concerns

16. **Have you experienced any outages or incidents?**
    - What happened?
    - Root cause?
    - How was it resolved?
    - **Why it matters:** Reveals weaknesses in current setup

17. **What would you change if you could start over?**
    - Reveals regrets and lessons learned
    - Provides insight into pain points

---

## 5. Common Issues & Solutions (All Platforms)

### 🚨 **Issue #1: Pods Not Spreading Across Zones**

**Symptoms:**
- All REC pods scheduled in same availability zone
- No rack awareness configured
- Zone failure would cause complete outage

**Diagnosis:**
```bash
# Check pod distribution
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:metadata.name,NODE:spec.nodeName,ZONE:spec.nodeSelector.topology\.kubernetes\.io/zone"

# Check if rack awareness is enabled
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.rackAwarenessNodeLabel}'
```

**Root Causes:**
1. Rack awareness not enabled in REC spec
2. Nodes not labeled with `topology.kubernetes.io/zone`
3. Insufficient nodes in other zones
4. ClusterRole not configured (operator can't read node labels)

**Solution:**
```bash
# 1. Verify all nodes have zone labels
kubectl get nodes -o custom-columns="NODE:metadata.name,ZONE:metadata.labels.topology\.kubernetes\.io/zone"

# If any nodes show <none>, they need to be labeled (usually automatic on cloud platforms)

# 2. Apply RBAC for rack awareness
kubectl apply -f deployments/single-region/03-rbac-rack-awareness.yaml

# 3. Enable rack awareness in REC
kubectl patch rec rec -n redis-enterprise --type merge -p '
spec:
  rackAwarenessNodeLabel: topology.kubernetes.io/zone
'

# 4. Verify pods are rescheduled across zones (may take time)
kubectl get pods -n redis-enterprise -l app=redis-enterprise -o wide
```

**Why this matters:**
- Without rack awareness, master and replica can be in same zone
- Zone failure = data loss and downtime
- With rack awareness, master and replica guaranteed in different zones

---

### 🚨 **Issue #2: PVC in Wrong Zone (Cloud Platforms)**

**Symptoms:**
- Pod stuck in Pending state
- Event: "volume node affinity conflict" or "no nodes available"
- PVC created in zone A, pod scheduled to zone B

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod rec-0 -n redis-enterprise | grep -A10 Events

# Check PVC zone
kubectl get pvc -n redis-enterprise -o yaml | grep topology.kubernetes.io/zone

# Check node zones
kubectl get nodes -o custom-columns="NODE:metadata.name,ZONE:metadata.labels.topology\.kubernetes\.io/zone"
```

**Root Cause:**
- Cloud block storage (EBS/GCE PD/Azure Disk) is zonal, not regional
- PVC created in zone A, but pod scheduled to node in zone B
- Volume cannot be attached across zones

**Solution:**
```bash
# Option 1: Use volumeBindingMode: WaitForFirstConsumer (RECOMMENDED)
# This delays PVC creation until pod is scheduled

# Check current volumeBindingMode
kubectl get sc <storage-class-name> -o jsonpath='{.volumeBindingMode}'

# If "Immediate", patch to "WaitForFirstConsumer"
kubectl patch storageclass <storage-class-name> -p '{"volumeBindingMode":"WaitForFirstConsumer"}'

# Option 2: Delete and recreate (DATA LOSS!)
# Only if no data or have backup
kubectl delete pvc <pvc-name> -n redis-enterprise
# PVC will be recreated automatically in correct zone
```

**Prevention:**
- **Always use `volumeBindingMode: WaitForFirstConsumer`** in storage class
- This is the default in most modern storage classes

**Why this matters:**
- Immediate binding creates PVC before pod is scheduled
- Can result in PVC in wrong zone
- WaitForFirstConsumer ensures PVC is created in same zone as pod

---

### 🚨 **Issue #3: Burstable QoS (Pod Eviction Risk)**

**Symptoms:**
- Pods evicted under memory/CPU pressure
- QoS class is "Burstable" instead of "Guaranteed"
- Unpredictable performance

**Diagnosis:**
```bash
# Check QoS class
kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.status.qosClass}'
echo ""

# Expected: Guaranteed
# If Burstable or BestEffort, this is a problem

# Check if limits != requests
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources}'
```

**Root Cause:**
- `limits` > `requests` (or limits not set)
- Kubernetes assigns Burstable QoS when limits != requests
- Burstable pods can be evicted when node is under pressure

**Solution:**
```bash
# Set limits = requests for Guaranteed QoS
kubectl patch rec rec -n redis-enterprise --type merge -p '
spec:
  redisEnterpriseNodeResources:
    limits:
      cpu: "4000m"
      memory: 15Gi
    requests:
      cpu: "4000m"
      memory: 15Gi
'

# Verify QoS after pods restart
kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.status.qosClass}'
```

**Why this matters:**
- **Guaranteed QoS:** Pod is NEVER evicted due to resource pressure
- **Burstable QoS:** Pod CAN be evicted if node is under pressure
- **Best Effort QoS:** Pod is evicted FIRST under pressure

---

### 🚨 **Issue #4: Using Deprecated Storage Class**

**Symptoms:**
- Using old provisioner (kubernetes.io/aws-ebs, kubernetes.io/gce-pd, kubernetes.io/azure-disk)
- Poor performance
- Cannot use advanced features (volume expansion, snapshots)

**Diagnosis:**
```bash
# Check storage class provisioner
kubectl get pvc -n redis-enterprise -o jsonpath='{.items[0].spec.storageClassName}'

# Get provisioner
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# Old provisioners (deprecated):
# - kubernetes.io/aws-ebs (use ebs.csi.aws.com)
# - kubernetes.io/gce-pd (use pd.csi.storage.gke.io)
# - kubernetes.io/azure-disk (use disk.csi.azure.com)
```

**Root Cause:**
- Using legacy in-tree provisioner instead of CSI driver
- In-tree provisioners are deprecated and will be removed

**Solution:**
```bash
# Cannot change storage class after PVC creation
# Must recreate cluster with new storage class

# 1. Backup data
# 2. Delete REC (this deletes PVCs if reclaimPolicy is Delete)
# 3. Create new storage class with CSI provisioner
# 4. Update REC manifest with new storage class
# 5. Recreate REC
# 6. Restore data

# Example: Create new storage class (AWS)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-csi
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
EOF
```

**Prevention:**
- Always use CSI drivers for new deployments
- Check provisioner before deploying

**Why this matters:**
- CSI drivers are the future of Kubernetes storage
- In-tree provisioners will be removed in future Kubernetes versions
- CSI drivers support more features (snapshots, cloning, etc.)

---

### 🚨 **Issue #5: No Backups Configured**

**Symptoms:**
- No backup configuration in REDB spec
- No cloud storage bucket configured
- No disaster recovery plan

**Diagnosis:**
```bash
# Check if backup is configured
kubectl get redb -n redis-enterprise -o yaml | grep -A10 backup

# If no output, backups are not configured
```

**Root Cause:**
- Backups not configured during initial deployment
- Lack of awareness about backup options

**Solution (Platform-Specific):**

**AWS (S3):**
```bash
# 1. Create S3 bucket
aws s3 mb s3://redis-backups-$(date +%s) --region <region>

# 2. Configure IRSA (recommended) or create credentials secret

# 3. Update REDB with backup config
kubectl patch redb <db-name> -n redis-enterprise --type merge -p '
spec:
  backup:
    interval: 24
    s3:
      awsSecretName: s3-backup-credentials  # Or omit if using IRSA
      bucketName: redis-backups-<timestamp>
      subdir: production/<db-name>
'
```

**GCP (GCS):**
```bash
# 1. Create GCS bucket
gcloud storage buckets create gs://redis-backups-$(date +%s) \
  --location=<region> \
  --uniform-bucket-level-access

# 2. Configure Workload Identity (recommended) or create credentials secret

# 3. Update REDB with backup config
kubectl patch redb <db-name> -n redis-enterprise --type merge -p '
spec:
  backup:
    interval: 24
    gcs:
      gcsSecretName: gcs-backup-credentials  # Or omit if using Workload Identity
      bucketName: redis-backups-<timestamp>
      subdir: production/<db-name>
'
```

**Azure (Blob Storage):**
```bash
# 1. Create storage account and container
az storage account create -n redisbackups<timestamp> -g <resource-group>
az storage container create -n redis-backups --account-name redisbackups<timestamp>

# 2. Configure Managed Identity (recommended) or create credentials secret

# 3. Update REDB with backup config
kubectl patch redb <db-name> -n redis-enterprise --type merge -p '
spec:
  backup:
    interval: 24
    abs:
      absSecretName: abs-backup-credentials  # Or omit if using Managed Identity
      container: redis-backups
      subdir: production/<db-name>
'
```

**Why this matters:**
- No backups = risk of permanent data loss
- Backups are required for disaster recovery
- Automated backups prevent human error

---

### 🚨 **Issue #6: OpenShift Automatic Operator Upgrades**

**Symptoms (OpenShift only):**
- Operator upgraded automatically without warning
- Cluster becomes unstable after upgrade
- Breaking changes introduced

**Diagnosis:**
```bash
# Check install plan approval strategy
oc get subscription -n redis-enterprise -o jsonpath='{.items[0].spec.installPlanApproval}'

# If "Automatic", this is a problem
```

**Root Cause:**
- OLM subscription set to `installPlanApproval: Automatic`
- Operator upgrades automatically when new version is available
- Can introduce breaking changes without testing

**Solution:**
```bash
# Change to Manual approval
oc patch subscription redis-enterprise-operator-cert \
  -n redis-enterprise \
  --type merge \
  -p '{"spec":{"installPlanApproval":"Manual"}}'

# Verify
oc get subscription -n redis-enterprise -o jsonpath='{.items[0].spec.installPlanApproval}'

# Expected: Manual
```

**Why this matters:**
- Automatic upgrades can break production clusters
- Manual approval allows testing in non-production first
- Provides control over maintenance windows

---

### 🚨 **Issue #7: On-Premises - Using NFS for Redis Storage**

**Symptoms (On-Premises only):**
- Redis databases using NFS-backed PVCs
- Intermittent connection issues
- Data corruption
- Poor performance

**Diagnosis:**
```bash
# Check storage class provisioner
kubectl get pvc -n redis-enterprise -o jsonpath='{.items[0].spec.storageClassName}'

# Get provisioner
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# If provisioner contains "nfs", this is a problem
```

**Root Cause:**
- NFS is a network file system, not block storage
- Redis requires block storage for proper file locking
- NFS has locking issues that can cause data corruption
- Network latency affects performance

**Solution:**
```bash
# NFS is NOT suitable for Redis Enterprise
# Must migrate to block storage

# Options:
# 1. VMware vSphere: Use vSphere CSI driver (vSAN or VMFS)
# 2. Bare metal/KVM: Use Ceph (Rook) or Portworx
# 3. Small deployments: Local SSDs with backup strategy

# Migration steps:
# 1. Backup all databases
# 2. Create new storage class with block storage provisioner
# 3. Delete REC (this deletes PVCs)
# 4. Update REC manifest with new storage class
# 5. Recreate REC
# 6. Restore databases from backup

# Example: Create Ceph RBD storage class
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/fstype: xfs
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
EOF
```

**Why this matters:**
- **NFS is fundamentally incompatible with Redis Enterprise**
- Can cause data corruption and loss
- Performance is unpredictable
- This is a **critical issue** that must be fixed immediately

**Alternative for shared storage needs:**
- If you need shared storage for backups, use NFS for backup destination only
- Never use NFS for Redis data (PVCs)

---

### 🚨 **Issue #8: On-Premises - No Load Balancer (Using NodePort)**

**Symptoms (On-Premises only):**
- Services exposed via NodePort instead of LoadBalancer
- Clients connect to node IP:port
- Connection issues when nodes are replaced
- No automatic failover

**Diagnosis:**
```bash
# Check service type
kubectl get svc -n redis-enterprise

# If TYPE is NodePort instead of LoadBalancer, this is a problem
```

**Root Cause:**
- No load balancer solution installed (MetalLB, hardware LB)
- Kubernetes cannot provision LoadBalancer services
- Falling back to NodePort

**Solution:**
```bash
# Option 1: Install MetalLB (most common)

# 1. Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# 2. Create IP address pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Adjust to your network
EOF

# 3. Create L2Advertisement (or BGPAdvertisement for BGP mode)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: production
  namespace: metallb-system
spec:
  ipAddressPools:
  - production
EOF

# 4. Verify MetalLB is running
kubectl get pods -n metallb-system

# 5. Services will now get LoadBalancer IPs automatically
kubectl get svc -n redis-enterprise
```

**Option 2: Use hardware load balancer**
- Configure external LB (F5, Citrix, HAProxy)
- Use `externalTrafficPolicy: Local` for better performance
- Requires manual configuration

**Why this matters:**
- NodePort is not suitable for production
- Clients must know node IPs (changes when nodes are replaced)
- No automatic failover
- LoadBalancer provides stable IP and automatic failover

---

### 🚨 **Issue #9: GDC Edge - No Backup Strategy for Local Storage**

**Symptoms (GDC Edge only):**
- Using local storage (no replication)
- No automated backups configured
- Single node failure = data loss

**Diagnosis:**
```bash
# Check storage class
kubectl get pvc -n redis-enterprise -o jsonpath='{.items[0].spec.storageClassName}'

# Get provisioner
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# If provisioner is "kubernetes.io/no-provisioner" or "local-static-provisioner", storage is local

# Check if backups are configured
kubectl get redb -n redis-enterprise -o yaml | grep -A10 backup

# If no output, backups are not configured
```

**Root Cause:**
- GDC Edge typically has 1-3 nodes with local storage
- Local storage is not replicated across nodes
- Node failure = data loss
- No backup strategy configured

**Solution:**
```bash
# Configure automated backups to Google Cloud Storage

# 1. Create GCS bucket
gcloud storage buckets create gs://redis-backups-gdc-edge-$(date +%s) \
  --location=<region> \
  --uniform-bucket-level-access

# 2. Configure Workload Identity (if GDC is connected to Google Cloud)
# See GDC Workload Identity section

# 3. Update REDB with backup config
kubectl patch redb <db-name> -n redis-enterprise --type merge -p '
spec:
  backup:
    interval: 12  # More frequent for edge (every 12 hours)
    gcs:
      bucketName: redis-backups-gdc-edge-<timestamp>
      subdir: edge/<cluster-name>/<db-name>
'

# 4. Verify backups are running
kubectl get redb <db-name> -n redis-enterprise -o jsonpath='{.status.lastBackupTime}'
```

**Alternative: Backup to on-premises storage**
```bash
# If no Google Cloud connectivity, use local NFS/SMB for backups
# (NFS is OK for backups, just not for Redis data)

kubectl patch redb <db-name> -n redis-enterprise --type merge -p '
spec:
  backup:
    interval: 12
    mount:
      path: /backup
      # Mount NFS volume for backups
'
```

**Why this matters:**
- GDC Edge is designed for edge locations (retail, manufacturing)
- Often has limited redundancy (1-3 nodes)
- Local storage + no backups = high risk of data loss
- Backups to cloud or remote storage are critical

---

## 6. Troubleshooting Guide (Platform-Specific)

### 🔧 **On-Premises Troubleshooting**

#### **Issue: Pods Stuck in Pending (Storage)**

**Symptoms:**
```bash
kubectl get pods -n redis-enterprise
# NAME    READY   STATUS    RESTARTS   AGE
# rec-0   0/1     Pending   0          5m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod rec-0 -n redis-enterprise | grep -A10 Events

# Common messages:
# - "FailedScheduling: 0/3 nodes are available: 3 pod has unbound immediate PersistentVolumeClaims"
# - "FailedAttachVolume: AttachVolume.Attach failed"
# - "FailedMount: MountVolume.SetUp failed"
```

**Root Causes & Solutions:**

**1. PVC not bound (no PV available):**
```bash
# Check PVC status
kubectl get pvc -n redis-enterprise

# If STATUS is "Pending", check storage class
kubectl get sc

# Verify provisioner is running:

# For vSphere CSI:
kubectl get pods -n vmware-system-csi
# All pods should be Running

# For Ceph (Rook):
kubectl get pods -n rook-ceph
kubectl get cephcluster -n rook-ceph
# CephCluster should be HEALTH_OK

# For Portworx:
kubectl get pods -n kube-system | grep portworx
pxctl status  # Run on any node
```

**2. vSphere CSI - No datastore available:**
```bash
# Check vSphere CSI driver logs
kubectl logs -n vmware-system-csi vsphere-csi-controller-0 -c vsphere-csi-controller

# Common errors:
# - "No compatible datastore found"
# - "Insufficient space on datastore"

# Solution: Check vSphere datastore capacity
# In vSphere UI: Storage → Datastores → Check free space
```

**3. Ceph - Insufficient OSDs:**
```bash
# Check Ceph cluster health
kubectl get cephcluster -n rook-ceph -o jsonpath='{.items[0].status.ceph.health}'

# If not "HEALTH_OK", check details:
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# Common issues:
# - "too few PGs per OSD" → Increase PG count
# - "OSD down" → Check OSD pods
# - "Insufficient space" → Add more OSDs

# Check OSD pods
kubectl get pods -n rook-ceph -l app=rook-ceph-osd

# Check OSD capacity
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd df
```

**4. Portworx - Node not initialized:**
```bash
# Check Portworx cluster status
kubectl get storagecluster -n kube-system

# Check Portworx node status
pxctl status  # Run on any node

# Common issues:
# - "Node not in quorum" → Check network connectivity
# - "Drive not added" → Check drive configuration
# - "License expired" → Renew license

# Check Portworx logs
kubectl logs -n kube-system -l name=portworx
```

---

#### **Issue: Pods Stuck in Pending (Scheduling)**

**Symptoms:**
```bash
kubectl get pods -n redis-enterprise
# NAME    READY   STATUS    RESTARTS   AGE
# rec-0   0/1     Pending   0          5m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod rec-0 -n redis-enterprise | grep -A10 Events

# Common messages:
# - "0/3 nodes are available: 3 Insufficient cpu"
# - "0/3 nodes are available: 3 Insufficient memory"
# - "0/3 nodes are available: 3 node(s) didn't match pod anti-affinity rules"
```

**Root Causes & Solutions:**

**1. Insufficient resources:**
```bash
# Check node resources
kubectl top nodes

# Check node allocatable resources
kubectl describe nodes | grep -A5 "Allocatable:"

# Solution: Add more nodes or reduce resource requests
```

**2. Pod anti-affinity (all nodes in same zone):**
```bash
# Check node labels
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone

# If all nodes have same zone label, pods can't spread
# Solution: Label nodes with different zones (even if logical)

kubectl label node <node1> topology.kubernetes.io/zone=zone-a
kubectl label node <node2> topology.kubernetes.io/zone=zone-b
kubectl label node <node3> topology.kubernetes.io/zone=zone-c
```

**3. Taints on nodes:**
```bash
# Check node taints
kubectl describe nodes | grep Taints

# If nodes have taints, add tolerations to REC spec
kubectl patch rec rec -n redis-enterprise --type merge -p '
spec:
  redisEnterpriseNodeResources:
    tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "redis"
      effect: "NoSchedule"
'
```

---

#### **Issue: MetalLB Not Assigning IPs**

**Symptoms:**
```bash
kubectl get svc -n redis-enterprise
# NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
# redis-enterprise-ui   LoadBalancer   10.96.100.50    <pending>     8443:30001/TCP
```

**Diagnosis:**
```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb -l component=controller

# Common errors:
# - "no available IPs" → IP pool exhausted
# - "no IPAddressPool found" → IPAddressPool not configured
```

**Root Causes & Solutions:**

**1. No IPAddressPool configured:**
```bash
# Check if IPAddressPool exists
kubectl get ipaddresspool -n metallb-system

# If empty, create one:
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Adjust to your network
EOF
```

**2. No L2Advertisement or BGPAdvertisement:**
```bash
# Check if advertisement exists
kubectl get l2advertisement -n metallb-system
kubectl get bgpadvertisement -n metallb-system

# If empty, create L2Advertisement:
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: production
  namespace: metallb-system
spec:
  ipAddressPools:
  - production
EOF
```

**3. IP pool exhausted:**
```bash
# Check IP allocations
kubectl get svc -A -o wide | grep LoadBalancer

# Count how many IPs are in use vs available
# Solution: Expand IP pool range

kubectl patch ipaddresspool production -n metallb-system --type merge -p '
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
  - 192.168.1.251-192.168.1.260  # Add more IPs
'
```

**4. IP conflict with existing network:**
```bash
# Test if IP is already in use
ping 192.168.1.240

# If responds, IP is in use (conflict)
# Solution: Use different IP range that's not in use
```

---

#### **Issue: Network Connectivity (On-Premises)**

**Symptoms:**
- Pods can't reach external services
- Pods can't reach other pods
- External clients can't reach LoadBalancer IPs

**Diagnosis:**
```bash
# Test pod-to-pod connectivity
kubectl run test-pod --image=nicolaka/netshoot -it --rm -- /bin/bash
# Inside pod:
ping <other-pod-ip>
curl http://<service-name>.<namespace>.svc.cluster.local

# Test pod-to-external connectivity
kubectl run test-pod --image=nicolaka/netshoot -it --rm -- /bin/bash
# Inside pod:
ping 8.8.8.8
curl https://google.com

# Test external-to-LoadBalancer connectivity
# From external machine:
curl http://<loadbalancer-ip>:8443
```

**Root Causes & Solutions:**

**1. CNI plugin not working:**
```bash
# Check CNI plugin pods
# Calico:
kubectl get pods -n kube-system -l k8s-app=calico-node

# Cilium:
kubectl get pods -n kube-system -l k8s-app=cilium

# Flannel:
kubectl get pods -n kube-system -l app=flannel

# If pods are not Running, check logs
kubectl logs -n kube-system <cni-pod-name>
```

**2. Firewall blocking traffic:**
```bash
# Check firewall rules on nodes
# RHEL/CentOS:
sudo firewall-cmd --list-all

# Ubuntu:
sudo ufw status

# Solution: Open required ports
# Redis Enterprise ports: 8001, 8070, 8071, 9443, 10000-19999
```

**3. Network policies blocking traffic:**
```bash
# Check network policies
kubectl get networkpolicy -n redis-enterprise

# Temporarily disable to test
kubectl delete networkpolicy --all -n redis-enterprise

# If connectivity works, network policy is too restrictive
# Re-create with correct rules
```

**4. MetalLB L2 mode - ARP not working:**
```bash
# Check if ARP is working
# From external machine:
arp -a | grep <loadbalancer-ip>

# If no entry, ARP is not working
# Common causes:
# - Switch blocking ARP
# - VLAN misconfiguration
# - MetalLB speaker not running on correct node

# Check which node is handling the IP
kubectl get pods -n metallb-system -l component=speaker -o wide

# Check speaker logs
kubectl logs -n metallb-system -l component=speaker
```

---

#### **Issue: vSphere CSI - Volume Attach Timeout**

**Symptoms:**
```bash
kubectl describe pod rec-0 -n redis-enterprise
# Events:
#   Warning  FailedAttachVolume  AttachVolume.Attach failed for volume "pvc-xxx" :
#   rpc error: code = Internal desc = failed to attach disk: timeout
```

**Diagnosis:**
```bash
# Check vSphere CSI controller logs
kubectl logs -n vmware-system-csi vsphere-csi-controller-0 -c vsphere-csi-controller

# Check vSphere CSI node logs (on the node where pod is scheduled)
kubectl logs -n vmware-system-csi vsphere-csi-node-<xxx> -c vsphere-csi-node
```

**Root Causes & Solutions:**

**1. vCenter connectivity issues:**
```bash
# Check vSphere CSI config
kubectl get secret vsphere-config-secret -n vmware-system-csi -o yaml

# Verify vCenter credentials are correct
# Test connectivity from node to vCenter
curl -k https://<vcenter-fqdn>
```

**2. VM has too many disks attached:**
```bash
# vSphere has limit of 60 disks per VM (SCSI controllers)
# Check in vSphere UI: VM → Edit Settings → Count disks

# Solution: Use fewer, larger disks or add more nodes
```

**3. Datastore latency:**
```bash
# Check vSphere datastore performance
# In vSphere UI: Storage → Datastores → Performance

# High latency (>20ms) can cause timeouts
# Solution: Use faster storage (SSD, NVMe) or check storage backend
```

---

#### **Issue: Ceph - Slow Performance**

**Symptoms:**
- High latency (>10ms)
- Low throughput
- Pods slow to start

**Diagnosis:**
```bash
# Check Ceph cluster health
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# Check Ceph performance
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd perf

# Check OSD latency
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd df

# Check slow requests
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail
```

**Root Causes & Solutions:**

**1. OSDs on HDD instead of SSD:**
```bash
# Check OSD device class
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree

# If device class is "hdd", performance will be poor
# Solution: Migrate to SSD OSDs
```

**2. Insufficient OSD resources:**
```bash
# Check OSD CPU/memory usage
kubectl top pods -n rook-ceph -l app=rook-ceph-osd

# If CPU/memory is high, increase OSD resources
# Edit CephCluster CR:
kubectl edit cephcluster -n rook-ceph

# Increase resources:
spec:
  storage:
    nodes:
    - name: <node-name>
      resources:
        limits:
          cpu: "2"
          memory: 4Gi
        requests:
          cpu: "1"
          memory: 2Gi
```

**3. Network latency between OSDs:**
```bash
# Test network latency between OSD nodes
# From one node to another:
ping <other-node-ip>

# Should be <1ms for local network
# If >5ms, check network infrastructure
```

**4. Too many placement groups (PGs):**
```bash
# Check PG count
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail

# Rule of thumb: 100-200 PGs per OSD
# If too many, reduce PG count:
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool set <pool-name> pg_num <new-count>
```

---

### 🔧 **GDC Troubleshooting**

#### **Issue: GDC Cluster Not Connected to Google Cloud**

**Symptoms:**
- No Cloud Logging
- No Cloud Monitoring
- Workload Identity not working

**Diagnosis:**
```bash
# Check if gke-connect is running
kubectl get pods -n gke-connect

# If no pods, cluster is not connected
```

**Root Causes & Solutions:**

**1. Cluster not registered with Google Cloud:**
```bash
# Register cluster with Google Cloud
gcloud container hub memberships register <cluster-name> \
  --context=<cluster-context> \
  --service-account-key-file=<key-file>

# Verify registration
gcloud container hub memberships list
```

**2. Network connectivity to Google Cloud:**
```bash
# Test connectivity from cluster
kubectl run test-pod --image=nicolaka/netshoot -it --rm -- /bin/bash
# Inside pod:
curl https://www.googleapis.com

# If fails, check firewall rules
# Required: Outbound HTTPS (443) to *.googleapis.com
```

---

#### **Issue: GDC Workload Identity Not Working**

**Symptoms:**
- Pods can't access Google Cloud services (Secret Manager, GCS)
- Error: "Permission denied" or "Unauthenticated"

**Diagnosis:**
```bash
# Check if service account has Workload Identity annotation
kubectl get sa -n redis-enterprise -o yaml | grep iam.gke.io/gcp-service-account

# If no annotation, Workload Identity is not configured
```

**Root Causes & Solutions:**

**1. Service account not annotated:**
```bash
# Annotate Kubernetes service account
kubectl annotate sa redis-enterprise-operator \
  -n redis-enterprise \
  iam.gke.io/gcp-service-account=<gcp-sa>@<project>.iam.gserviceaccount.com
```

**2. IAM binding not created:**
```bash
# Create IAM binding
gcloud iam service-accounts add-iam-policy-binding \
  <gcp-sa>@<project>.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:<project>.svc.id.goog[redis-enterprise/redis-enterprise-operator]"
```

**3. GCP service account missing permissions:**
```bash
# Grant required permissions
# For Secret Manager:
gcloud projects add-iam-policy-binding <project> \
  --member="serviceAccount:<gcp-sa>@<project>.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# For GCS:
gcloud projects add-iam-policy-binding <project> \
  --member="serviceAccount:<gcp-sa>@<project>.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

---

## 7. Migration Guide (Cloud ↔ On-Premises)

### 📦 **Migration Scenarios**

| From | To | Complexity | Downtime | Use Case |
|------|-----|------------|----------|----------|
| **Cloud → On-Prem** | AWS/GCP/Azure → On-Prem | High | Hours | Data residency, cost optimization |
| **On-Prem → Cloud** | On-Prem → AWS/GCP/Azure | Medium | Hours | Cloud migration, scalability |
| **Cloud → Cloud** | AWS → GCP, GCP → Azure, etc. | Medium | Hours | Multi-cloud, vendor change |
| **On-Prem → GDC** | On-Prem → GDC | Low | Minutes | Hybrid cloud, Google tools |

---

### 📋 **Migration Checklist (All Scenarios)**

**Pre-Migration (1-2 weeks before):**
- [ ] Document current architecture (nodes, storage, networking)
- [ ] Test backup/restore procedure
- [ ] Measure current performance (baseline)
- [ ] Plan maintenance window (off-peak hours)
- [ ] Prepare rollback plan
- [ ] Notify stakeholders

**Migration Day:**
- [ ] Create final backup
- [ ] Verify backup integrity
- [ ] Deploy target cluster
- [ ] Restore data
- [ ] Validate data integrity
- [ ] Update DNS/load balancer
- [ ] Test application connectivity
- [ ] Monitor for issues

**Post-Migration (1 week after):**
- [ ] Monitor performance (compare to baseline)
- [ ] Verify backups are running
- [ ] Update documentation
- [ ] Decommission old cluster (after retention period)

---

### 🔄 **Migration Method 1: Backup/Restore (Recommended)**

**Best for:**
- One-time migration
- Acceptable downtime (hours)
- Different Kubernetes platforms

**Steps:**

**1. Backup from source cluster:**
```bash
# Set source context
kubectl config use-context <source-cluster>

# Create backup of all databases
for db in $(kubectl get redb -n redis-enterprise -o name); do
  db_name=$(echo $db | cut -d'/' -f2)

  # Trigger backup
  kubectl patch redb $db_name -n redis-enterprise --type merge -p '
  spec:
    backup:
      interval: 1  # Trigger immediate backup
  '

  echo "Backup triggered for $db_name"
done

# Wait for backups to complete
kubectl get redb -n redis-enterprise -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.lastBackupTime}{"\n"}{end}'

# Download backups from cloud storage
# AWS S3:
aws s3 sync s3://<bucket>/redis-backups ./backups/

# GCP GCS:
gcloud storage cp -r gs://<bucket>/redis-backups ./backups/

# Azure Blob:
az storage blob download-batch -s redis-backups -d ./backups/ --account-name <account>
```

**2. Deploy target cluster:**
```bash
# Set target context
kubectl config use-context <target-cluster>

# Deploy Redis Enterprise Operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml

# Create namespace
kubectl create namespace redis-enterprise

# Deploy REC (adjust for target platform)
kubectl apply -f rec.yaml -n redis-enterprise

# Wait for REC to be ready
kubectl wait --for=condition=ready pod -l app=redis-enterprise -n redis-enterprise --timeout=600s
```

**3. Upload backups to target storage:**
```bash
# Upload backups to target cloud storage
# AWS S3:
aws s3 sync ./backups/ s3://<target-bucket>/redis-backups/

# GCP GCS:
gcloud storage cp -r ./backups/ gs://<target-bucket>/redis-backups/

# Azure Blob:
az storage blob upload-batch -s ./backups/ -d redis-backups --account-name <target-account>

# On-Premises (NFS/SMB):
cp -r ./backups/ /mnt/nfs/redis-backups/
```

**4. Restore databases:**
```bash
# Create REDB with restore configuration
cat <<EOF | kubectl apply -f -
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: <db-name>
  namespace: redis-enterprise
spec:
  memorySize: 1GB
  # Restore from backup
  backup:
    s3:  # or gcs, abs, mount
      bucketName: <target-bucket>
      subdir: redis-backups/<db-name>
  # Specify backup file to restore
  restore:
    s3:  # or gcs, abs, mount
      bucketName: <target-bucket>
      subdir: redis-backups/<db-name>
      # Optional: specific backup file
      # backupFile: backup-2025-01-06-12-00-00.rdb
EOF

# Wait for restore to complete
kubectl get redb <db-name> -n redis-enterprise -o jsonpath='{.status.status}'
# Should show "active" when complete
```

**5. Validate data:**
```bash
# Get database endpoint
kubectl get redb <db-name> -n redis-enterprise -o jsonpath='{.status.databaseURL}'

# Connect and verify data
redis-cli -h <db-host> -p <db-port> -a <password>
> DBSIZE
> GET <test-key>
> INFO keyspace
```

**6. Update application configuration:**
```bash
# Update application to point to new Redis endpoint
# Update DNS, ConfigMaps, Secrets, etc.

# Example: Update ConfigMap
kubectl patch configmap app-config -n app-namespace --type merge -p '
data:
  REDIS_HOST: "<new-redis-host>"
  REDIS_PORT: "<new-redis-port>"
'

# Restart application pods
kubectl rollout restart deployment app -n app-namespace
```

**Downtime:** 2-6 hours (depending on data size)

---

### 🔄 **Migration Method 2: Active-Active Replication (Zero Downtime)**

**Best for:**
- Zero downtime requirement
- Gradual migration
- Multi-cloud strategy

**Requirements:**
- Redis Enterprise Active-Active license
- Network connectivity between clusters
- DNS management

**Steps:**

**1. Deploy target cluster:**
```bash
# Same as Method 1, step 2
```

**2. Create Active-Active database:**
```bash
# On source cluster, convert database to Active-Active
# This requires Redis Enterprise UI or REST API

# Via REST API:
curl -k -u "<user>:<password>" -X POST \
  https://<source-rec>:9443/v1/crdbs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "<db-name>-aa",
    "memory_size": 1073741824,
    "replication": true,
    "instances": [
      {
        "cluster": {
          "url": "https://<source-rec>:9443",
          "credentials": {
            "username": "<user>",
            "password": "<password>"
          }
        }
      },
      {
        "cluster": {
          "url": "https://<target-rec>:9443",
          "credentials": {
            "username": "<user>",
            "password": "<password>"
          }
        }
      }
    ]
  }'
```

**3. Wait for initial sync:**
```bash
# Monitor replication status
# Via REST API:
curl -k -u "<user>:<password>" \
  https://<source-rec>:9443/v1/crdbs/<crdb-id>

# Check "sync_status" field
# Should be "synced" when complete
```

**4. Update application to use both endpoints:**
```bash
# Configure application to use Active-Active endpoints
# Most Redis clients support multiple endpoints

# Example: Node.js (ioredis)
const Redis = require('ioredis');
const cluster = new Redis.Cluster([
  { host: '<source-endpoint>', port: 12000 },
  { host: '<target-endpoint>', port: 12000 }
]);
```

**5. Gradually shift traffic to target:**
```bash
# Use DNS weighted routing or load balancer
# Gradually increase weight to target cluster

# Example: AWS Route 53 weighted routing
# 90% source, 10% target → 50/50 → 10% source, 90% target → 100% target
```

**6. Decommission source cluster:**
```bash
# After all traffic is on target, remove source instance from Active-Active
# Via REST API:
curl -k -u "<user>:<password>" -X DELETE \
  https://<source-rec>:9443/v1/crdbs/<crdb-id>/instances/<source-instance-id>

# Convert to regular database (optional)
# This removes Active-Active overhead
```

**Downtime:** 0 (zero downtime)

**Cost:** Higher (requires Active-Active license + dual infrastructure during migration)

---

### 🌐 **Network Considerations for Migration**

#### **Cloud → On-Premises**

**Challenges:**
- Network connectivity (VPN, Direct Connect, ExpressRoute)
- Firewall rules
- DNS resolution

**Solutions:**

**1. VPN Connection:**
```bash
# AWS Site-to-Site VPN
aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id <cgw-id> \
  --vpn-gateway-id <vgw-id>

# GCP Cloud VPN
gcloud compute vpn-tunnels create <tunnel-name> \
  --peer-address=<on-prem-ip> \
  --shared-secret=<secret> \
  --target-vpn-gateway=<gateway>

# Azure VPN Gateway
az network vpn-connection create \
  --name <connection-name> \
  --resource-group <rg> \
  --vnet-gateway1 <vnet-gateway> \
  --local-gateway2 <local-gateway> \
  --shared-key <secret>
```

**2. Firewall Rules:**
```bash
# Open required ports for Redis Enterprise replication
# Source: Cloud cluster
# Destination: On-premises cluster
# Ports: 8001, 8070, 8071, 9443, 10000-19999

# AWS Security Group:
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 8001 \
  --cidr <on-prem-cidr>

# GCP Firewall Rule:
gcloud compute firewall-rules create allow-redis-replication \
  --allow tcp:8001,tcp:8070,tcp:8071,tcp:9443,tcp:10000-19999 \
  --source-ranges <on-prem-cidr>

# Azure NSG:
az network nsg rule create \
  --resource-group <rg> \
  --nsg-name <nsg> \
  --name allow-redis-replication \
  --priority 100 \
  --source-address-prefixes <on-prem-cidr> \
  --destination-port-ranges 8001 8070 8071 9443 10000-19999 \
  --protocol Tcp
```

**3. DNS Resolution:**
```bash
# Option 1: Use IP addresses instead of DNS names
# Option 2: Configure DNS forwarding
# Option 3: Use /etc/hosts on nodes

# Example: Add to /etc/hosts on all nodes
echo "<on-prem-ip> redis-enterprise.on-prem.local" | sudo tee -a /etc/hosts
```

---

#### **On-Premises → Cloud**

**Challenges:**
- Egress firewall rules
- NAT gateway
- Cloud provider limits

**Solutions:**

**1. Egress Firewall:**
```bash
# Allow outbound traffic to cloud provider
# Destination: Cloud cluster CIDR
# Ports: 8001, 8070, 8071, 9443, 10000-19999

# RHEL/CentOS firewalld:
sudo firewall-cmd --permanent --add-rich-rule='
  rule family="ipv4"
  destination address="<cloud-cidr>"
  port protocol="tcp" port="8001" accept'
sudo firewall-cmd --reload

# Ubuntu ufw:
sudo ufw allow out to <cloud-cidr> port 8001 proto tcp
```

**2. NAT Gateway (for private clusters):**
```bash
# AWS NAT Gateway:
aws ec2 create-nat-gateway \
  --subnet-id <public-subnet-id> \
  --allocation-id <eip-allocation-id>

# GCP Cloud NAT:
gcloud compute routers nats create <nat-name> \
  --router=<router> \
  --region=<region> \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges

# Azure NAT Gateway:
az network nat gateway create \
  --resource-group <rg> \
  --name <nat-name> \
  --public-ip-addresses <public-ip>
```

---

### 💾 **Data Validation After Migration**

**Critical checks:**

```bash
# 1. Compare key count
# Source:
redis-cli -h <source-host> -p <source-port> -a <password> DBSIZE

# Target:
redis-cli -h <target-host> -p <target-port> -a <password> DBSIZE

# Should match exactly

# 2. Compare sample keys
# Source:
redis-cli -h <source-host> -p <source-port> -a <password> GET <key>

# Target:
redis-cli -h <target-host> -p <target-port> -a <password> GET <key>

# Should match exactly

# 3. Compare INFO output
# Source:
redis-cli -h <source-host> -p <source-port> -a <password> INFO

# Target:
redis-cli -h <target-host> -p <target-port> -a <password> INFO

# Compare: used_memory, total_keys, etc.

# 4. Run application smoke tests
# Test critical application flows
# Verify data integrity
```

---

## 8. Cost Comparison (Cloud vs On-Premises)

### 💰 **Total Cost of Ownership (TCO) Analysis**

**Cost Components:**

| Component | Cloud (AWS/GCP/Azure) | On-Premises | Notes |
|-----------|----------------------|-------------|-------|
| **Infrastructure** | Pay-per-use (hourly) | Upfront CapEx | Cloud: OpEx, On-Prem: CapEx |
| **Compute** | $0.10-0.50/hour per node | $5K-15K per server | Cloud: m5.2xlarge ~$0.38/hr |
| **Storage** | $0.10-0.20/GB/month | $200-500/TB (SSD) | Cloud: gp3/pd-ssd, On-Prem: SSD/NVMe |
| **Network** | $0.01-0.09/GB egress | Included (after initial setup) | Cloud: Egress charges, On-Prem: One-time |
| **Load Balancer** | $20-30/month | $0 (MetalLB) or $10K+ (F5) | Cloud: Managed, On-Prem: Software or hardware |
| **Backup Storage** | $0.02-0.05/GB/month | Included (local) or cloud | Cloud: S3/GCS/Blob, On-Prem: NFS or cloud |
| **Management** | Included (managed K8s) | 1-2 FTE ($100K-200K/year) | Cloud: Less ops overhead |
| **Licensing** | Same | Same | Redis Enterprise license (same cost) |
| **Power/Cooling** | Included | $100-200/server/month | On-Prem only |
| **Datacenter** | Included | Rent or owned | On-Prem only |

---

### 📊 **Example: 3-Node Redis Enterprise Cluster**

**Assumptions:**
- 3 nodes, 8 vCPU, 32GB RAM each
- 500GB storage per node (1.5TB total)
- 1TB data egress per month
- 3-year analysis

---

#### **Cloud (AWS EKS) - Monthly Cost**

| Item | Specification | Monthly Cost |
|------|---------------|--------------|
| **Compute** | 3x m5.2xlarge (8 vCPU, 32GB) @ $0.384/hr | $829 |
| **Storage** | 1.5TB gp3 @ $0.08/GB/month | $120 |
| **EKS Control Plane** | $0.10/hour | $73 |
| **Load Balancer** | 1x NLB | $25 |
| **Data Transfer** | 1TB egress @ $0.09/GB | $90 |
| **Backup (S3)** | 500GB @ $0.023/GB/month | $12 |
| **CloudWatch** | Logs + metrics | $50 |
| **Total Monthly** | | **$1,199** |
| **Total 3-Year** | | **$43,164** |

**Additional Costs:**
- Support: $100-500/month (optional)
- Reserved Instances: -30% if committed (3-year RI)
- Savings Plans: -20-30% if committed

**With 3-Year Reserved Instances:**
- Compute: $829 → $580 (-30%)
- **Total Monthly: $950**
- **Total 3-Year: $34,200**

---

#### **Cloud (GCP GKE) - Monthly Cost**

| Item | Specification | Monthly Cost |
|------|---------------|--------------|
| **Compute** | 3x n2-standard-8 (8 vCPU, 32GB) @ $0.388/hr | $838 |
| **Storage** | 1.5TB pd-ssd @ $0.17/GB/month | $255 |
| **GKE Control Plane** | Free (Standard) or $0.10/hr (Autopilot) | $0-73 |
| **Load Balancer** | 1x Network LB | $20 |
| **Data Transfer** | 1TB egress @ $0.12/GB | $120 |
| **Backup (GCS)** | 500GB @ $0.020/GB/month | $10 |
| **Cloud Logging** | Logs + metrics | $50 |
| **Total Monthly** | | **$1,293** |
| **Total 3-Year** | | **$46,548** |

**With 3-Year Committed Use Discounts:**
- Compute: $838 → $545 (-35%)
- **Total Monthly: $1,000**
- **Total 3-Year: $36,000**

---

#### **Cloud (Azure AKS) - Monthly Cost**

| Item | Specification | Monthly Cost |
|------|---------------|--------------|
| **Compute** | 3x Standard_D8s_v3 (8 vCPU, 32GB) @ $0.384/hr | $829 |
| **Storage** | 1.5TB Premium SSD @ $0.135/GB/month | $203 |
| **AKS Control Plane** | Free | $0 |
| **Load Balancer** | 1x Standard LB | $25 |
| **Data Transfer** | 1TB egress @ $0.087/GB | $87 |
| **Backup (Blob)** | 500GB @ $0.018/GB/month | $9 |
| **Azure Monitor** | Logs + metrics | $50 |
| **Total Monthly** | | **$1,203** |
| **Total 3-Year** | | **$43,308** |

**With 3-Year Reserved Instances:**
- Compute: $829 → $538 (-35%)
- **Total Monthly: $912**
- **Total 3-Year: $32,832**

---

#### **On-Premises (VMware vSphere) - 3-Year TCO**

**Upfront Costs (Year 0):**

| Item | Specification | Cost |
|------|---------------|------|
| **Servers** | 3x Dell R650 (2x Intel Xeon, 256GB RAM, 2x 1TB NVMe) | $30,000 |
| **Network** | 2x 10GbE switches | $5,000 |
| **Storage** | Included in servers (local NVMe) | $0 |
| **Rack/PDU** | 1x rack, 2x PDU | $2,000 |
| **Installation** | Professional services | $3,000 |
| **Total Upfront** | | **$40,000** |

**Recurring Costs (Monthly):**

| Item | Specification | Monthly Cost |
|------|---------------|--------------|
| **Power** | 3 servers @ 300W avg, $0.10/kWh | $65 |
| **Cooling** | 1.5x power consumption | $98 |
| **Datacenter** | Colocation or owned | $500 |
| **Network** | Internet + VPN | $200 |
| **Backup** | S3/GCS for offsite backups (500GB) | $12 |
| **Management** | 0.5 FTE @ $150K/year | $6,250 |
| **Total Monthly** | | **$7,125** |

**3-Year TCO:**
- Upfront: $40,000
- Recurring: $7,125 × 36 = $256,500
- **Total 3-Year: $296,500**

**Wait, this is MORE expensive than cloud!**

**Why?** Management cost (0.5 FTE) is the biggest factor.

**Adjusted (with existing IT staff):**
- If you already have IT staff managing infrastructure, marginal cost is lower
- Assume 0.1 FTE incremental (not 0.5 FTE dedicated)
- Management: $6,250 → $1,250/month

**Adjusted 3-Year TCO:**
- Upfront: $40,000
- Recurring: $2,125 × 36 = $76,500
- **Total 3-Year: $116,500**

**Now on-prem is cheaper!**

---

#### **On-Premises (Bare Metal + Ceph) - 3-Year TCO**

**Upfront Costs (Year 0):**

| Item | Specification | Cost |
|------|---------------|------|
| **Compute Nodes** | 3x Dell R650 (2x Intel Xeon, 256GB RAM, 2x 500GB NVMe) | $27,000 |
| **Storage Nodes** | 3x Dell R740xd (2x Intel Xeon, 128GB RAM, 12x 2TB SSD) | $45,000 |
| **Network** | 2x 10GbE switches | $5,000 |
| **Rack/PDU** | 1x rack, 2x PDU | $2,000 |
| **Installation** | Professional services | $5,000 |
| **Total Upfront** | | **$84,000** |

**Recurring Costs (Monthly):**

| Item | Specification | Monthly Cost |
|------|---------------|--------------|
| **Power** | 6 servers @ 300W avg, $0.10/kWh | $130 |
| **Cooling** | 1.5x power consumption | $195 |
| **Datacenter** | Colocation or owned | $800 |
| **Network** | Internet + VPN | $200 |
| **Backup** | S3/GCS for offsite backups (500GB) | $12 |
| **Management** | 0.2 FTE @ $150K/year (Ceph is complex) | $2,500 |
| **Total Monthly** | | **$3,837** |

**3-Year TCO:**
- Upfront: $84,000
- Recurring: $3,837 × 36 = $138,132
- **Total 3-Year: $222,132**

**Still cheaper than cloud (with committed discounts: $32K-36K)**

**But:** Higher upfront cost, more complexity (Ceph management)

---

### 📈 **Break-Even Analysis**

**When does on-premises become cheaper than cloud?**

**Assumptions:**
- Cloud: $1,000/month (with 3-year commitment)
- On-Prem: $40K upfront + $2,125/month (with existing IT staff)

**Break-even calculation:**
```
Cloud cost = On-Prem cost
$1,000 × months = $40,000 + $2,125 × months
$1,000 × months - $2,125 × months = $40,000
-$1,125 × months = $40,000
months = -35.6

Wait, this is negative! Cloud is cheaper!
```

**Corrected (on-prem is cheaper per month):**
```
Cloud: $1,000/month
On-Prem: $40,000 upfront + $2,125/month

Actually, on-prem is MORE expensive per month ($2,125 vs $1,000)
So cloud is cheaper in this scenario!
```

**When is on-prem cheaper?**

**Scenario 1: Large scale (10+ nodes)**
- Cloud: $1,000/month × 3.33 (10 nodes / 3 nodes) = $3,333/month
- On-Prem: $40,000 × 3.33 = $133K upfront + $2,125 × 3.33 = $7,083/month

Still more expensive!

**Scenario 2: Existing datacenter + IT staff**
- Cloud: $1,000/month
- On-Prem: $40,000 upfront + $163/month (power + cooling + backup only)

```
$1,000 × months = $40,000 + $163 × months
$1,000 × months - $163 × months = $40,000
$837 × months = $40,000
months = 47.8 (~ 4 years)
```

**Break-even: ~4 years**

**Scenario 3: Very large scale (100+ nodes) + existing datacenter**
- Cloud: $1,000/month × 33.33 = $33,333/month
- On-Prem: $400K upfront + $5,000/month (power + cooling + backup + 1 FTE)

```
$33,333 × months = $400,000 + $5,000 × months
$33,333 × months - $5,000 × months = $400,000
$28,333 × months = $400,000
months = 14.1 (~ 14 months)
```

**Break-even: ~14 months**

---

### 🎯 **Decision Matrix: Cloud vs On-Premises**

| Factor | Cloud | On-Premises | Winner |
|--------|-------|-------------|--------|
| **Upfront Cost** | Low ($0) | High ($40K-100K+) | ☁️ Cloud |
| **Monthly Cost (small)** | $1,000-1,500 | $2,000-7,000 | ☁️ Cloud |
| **Monthly Cost (large)** | $10,000-50,000 | $5,000-15,000 | 🏢 On-Prem |
| **Scalability** | Instant | Weeks (order hardware) | ☁️ Cloud |
| **Flexibility** | High (scale up/down) | Low (fixed capacity) | ☁️ Cloud |
| **Management** | Low (managed K8s) | High (DIY) | ☁️ Cloud |
| **Data Residency** | Limited (region-based) | Full control | 🏢 On-Prem |
| **Compliance** | Shared responsibility | Full control | 🏢 On-Prem |
| **Network Latency** | Varies (region-based) | Low (local) | 🏢 On-Prem |
| **Egress Costs** | High ($0.09/GB) | Low (after VPN) | 🏢 On-Prem |
| **Disaster Recovery** | Easy (multi-region) | Complex (multi-site) | ☁️ Cloud |

**Recommendation:**

**Choose Cloud if:**
- ✅ Small to medium scale (< 20 nodes)
- ✅ Need rapid scaling
- ✅ Limited IT staff
- ✅ Want managed services
- ✅ Multi-region DR required
- ✅ Startup or fast-growing company

**Choose On-Premises if:**
- ✅ Large scale (50+ nodes)
- ✅ Existing datacenter + IT staff
- ✅ Data residency requirements (government, healthcare)
- ✅ Low egress (data stays local)
- ✅ Long-term commitment (5+ years)
- ✅ Compliance requirements (full control)

**Choose Hybrid (GDC or Multi-Cloud) if:**
- ✅ Need both cloud and on-prem
- ✅ Data residency + cloud tools
- ✅ Gradual cloud migration
- ✅ Disaster recovery across environments

---

## 9. Best Practices Validation (All Platforms)

### ✅ **Use Validation Runbook**

**During the meeting, run through:**

[VALIDATION-RUNBOOK.md](VALIDATION-RUNBOOK.md)

**Priority checks (20 minutes):**

**1. Architecture (5 min)**
- [ ] Minimum 3 nodes (odd number)
- [ ] Pod anti-affinity enabled
- [ ] Multi-AZ deployment (3 zones)
- [ ] Spare Kubernetes nodes available

**2. Storage (5 min)**
- [ ] Block storage with CSI driver (not deprecated provisioner)
- [ ] Correct storage class for platform:
  - AWS: gp3 (not gp2)
  - GCP: pd-ssd or pd-balanced (not standard)
  - Azure: Premium_LRS (not Standard_LRS)
  - OpenShift: Platform-specific
- [ ] Volume size = 5x memory
- [ ] Volume expansion enabled
- [ ] volumeBindingMode: WaitForFirstConsumer

**3. Quality of Service (3 min)**
- [ ] Guaranteed QoS (limits = requests)
- [ ] PriorityClass configured (optional but recommended)

**4. Security (5 min)**
- [ ] TLS enabled on databases
- [ ] Network policies configured
- [ ] Secrets management (External Secrets or cloud-native)
- [ ] Cloud-native authentication:
  - AWS: IRSA
  - GCP: Workload Identity
  - Azure: Workload Identity or Managed Identity
  - OpenShift: Service accounts

**5. Monitoring (2 min)**
- [ ] Prometheus metrics available
- [ ] Alerting rules configured
- [ ] Dashboards created

**Total: ~20 minutes**

---

## 7. Security & Compliance Review (All Platforms)

### 🔐 **Security Checklist**

| Category | Check | Status | Notes |
|----------|-------|--------|-------|
| **Encryption** | TLS enabled on databases | ☐ | |
| | TLS for replication | ☐ | |
| | Encryption at rest (cloud default) | ☐ | |
| **Authentication** | Strong passwords (16+ chars) | ☐ | |
| | External Secrets Operator | ☐ | |
| | Cloud-native auth (IRSA/WI/MI) | ☐ | |
| **Authorization** | RBAC configured | ☐ | |
| | Network policies | ☐ | |
| | Pod Security Standards/SCCs | ☐ | |
| **Audit** | Audit logging enabled | ☐ | |
| | Cloud audit logs | ☐ | |
| **Secrets** | No secrets in Git | ☐ | |
| | Secrets rotation policy | ☐ | |
| **Compliance** | Data residency requirements met | ☐ | |
| | Compliance framework (SOC2/HIPAA/PCI) | ☐ | |

**Questions to ask:**

- ✅ **Do you have a security compliance framework?** (SOC2, HIPAA, PCI-DSS, GDPR)
- ✅ **Who has access to the cluster?** (RBAC, IAM)
- ✅ **How do you rotate secrets?** (Manual, automated)
- ✅ **Do you have audit logging requirements?**
- ✅ **Are there data residency requirements?** (Must stay in specific region/country)

---

## 8. Performance & Scalability (All Platforms)

### ⚡ **Performance Review**

**Metrics to review:**

| Metric | Command | Good | Warning | Critical |
|--------|---------|------|---------|----------|
| **CPU Usage** | `kubectl top nodes` | < 60% | 60-80% | > 80% |
| **Memory Usage** | `kubectl top nodes` | < 70% | 70-85% | > 85% |
| **Disk Usage** | Check in cloud console | < 70% | 70-85% | > 85% |
| **Latency** | Check in Grafana | < 1ms | 1-5ms | > 5ms |
| **QPS** | Check in Grafana | Varies | - | - |
| **Evictions** | `kubectl get events \| grep Evicted` | 0 | > 0 | Many |

**Questions to ask:**

1. **What is your current QPS?**
2. **What is your peak QPS?**
3. **What is your average latency?**
4. **Have you done load testing?**
5. **What is your scaling strategy?**
   - Vertical (bigger nodes)
   - Horizontal (more nodes)
   - Both

---

### 📈 **Capacity Planning**

**Calculate current capacity:**

```bash
# Get current resources
NODES=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}')
CPU=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.cpu}' | sed 's/m//')
MEMORY=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}' | sed 's/Gi//')

echo "Current REC capacity:"
echo "  Nodes: $NODES"
echo "  CPU per node: ${CPU}m"
echo "  Memory per node: ${MEMORY}Gi"
echo "  Total CPU: $((NODES * CPU))m"
echo "  Total Memory: $((NODES * MEMORY))Gi"

# Calculate available capacity for databases
# Rule of thumb: ~70% of total memory available for databases
DB_MEMORY=$((NODES * MEMORY * 70 / 100))
echo "  Available for databases: ~${DB_MEMORY}Gi"
```

**Example:**
```
Current REC capacity:
  Nodes: 3
  CPU per node: 4000m
  Memory per node: 15Gi
  Total CPU: 12000m
  Total Memory: 45Gi
  Available for databases: ~31Gi
```

**Questions to ask:**

- ✅ **How much headroom do you have?**
  - Current usage vs total capacity
  - Recommendation: Keep 20-30% headroom

- ✅ **When do you plan to scale?**
  - Proactive (before hitting limits)
  - Reactive (after hitting limits)

- ✅ **What is your scaling trigger?**
  - CPU threshold (e.g., 70%)
  - Memory threshold (e.g., 75%)
  - QPS threshold
  - Manual

---

## 9. Operational Readiness (All Platforms)

### 🛠️ **Operations Checklist**

| Category | Check | Status | Notes |
|----------|-------|--------|-------|
| **Deployment** | GitOps configured (ArgoCD/Flux) | ☐ | |
| | CI/CD pipeline | ☐ | |
| | Rollback procedure documented | ☐ | |
| **Monitoring** | Prometheus/Grafana | ☐ | |
| | Cloud-native monitoring | ☐ | |
| | Alerting configured | ☐ | |
| | Alert routing (PagerDuty/Slack) | ☐ | |
| **Backup** | Automated backups | ☐ | |
| | Backup testing (restore test) | ☐ | |
| | Restore procedure documented | ☐ | |
| | Backup retention policy | ☐ | |
| **Documentation** | Architecture diagram | ☐ | |
| | Runbooks (common scenarios) | ☐ | |
| | On-call procedures | ☐ | |
| | Escalation path | ☐ | |
| **Training** | Team trained on Redis Enterprise | ☐ | |
| | Knowledge transfer completed | ☐ | |
| | Access to Redis support | ☐ | |

**Questions to ask:**

- ✅ **Do you have runbooks for common scenarios?**
  - Node failure
  - Pod failure
  - Database failure
  - Cluster upgrade
  - Scaling operations

- ✅ **Have you tested your backup/restore procedure?**
  - When was the last restore test?
  - How long does restore take?
  - Is it documented?

- ✅ **Do you have an on-call rotation?**
  - Who is on-call?
  - What is the escalation path?
  - What is the SLA for response?

- ✅ **What is your incident response process?**
  - Detection (monitoring/alerting)
  - Triage (severity assessment)
  - Response (runbooks)
  - Resolution (fix)
  - Post-mortem (lessons learned)

---

## 10. Meeting Agenda Template

### 📅 **Suggested Agenda (90 minutes)**

**Introduction (10 min)**
- Introductions (names, roles)
- Meeting objectives
- Agenda review
- Set expectations

**Current State Review (20 min)**
- Architecture overview (client presents)
- Walk through deployment
- Review monitoring dashboards
- Discuss current usage and growth

**Technical Deep Dive (30 min)**
- Kubernetes cluster configuration
- Redis Enterprise configuration
- Storage and networking
- Security and compliance
- Platform-specific items

**Best Practices Validation (20 min)**
- Run through validation checklist
- Identify gaps
- Discuss remediation
- Prioritize recommendations

**Performance & Scalability (10 min)**
- Review current metrics
- Capacity planning
- Scaling strategy
- Growth projections

**Action Items & Next Steps (10 min)**
- Document findings
- Prioritize recommendations (P1/P2/P3)
- Assign action items (owner, due date)
- Schedule follow-up

---

### 📝 **Meeting Notes Template**

```markdown
# Redis Enterprise Implementation Review
Date: [DATE]
Attendees: [NAMES]
Platform: [ ] AWS EKS  [ ] Google GKE  [ ] Azure AKS  [ ] OpenShift  [ ] On-Premises  [ ] Google Distributed Cloud (GDC)

## Current State
- Kubernetes Version/Distribution: (e.g., 1.28, Rancher RKE2, Tanzu, GKE, etc.)
- Platform Mode: (e.g., EKS, GKE Standard/Autopilot, AKS, OpenShift, On-Prem VMware, GDC Hosted/Virtual/Edge)
- Infrastructure: (e.g., AWS, GCP, Azure, VMware vSphere, Bare Metal)
- REC Version:
- Number of REC Nodes:
- Number of Databases:
- Current QPS:
- Current Data Size:

## Findings

### ✅ Strengths
-

### ⚠️ Areas for Improvement
-

### 🚨 Critical Issues
-

## Recommendations

### Priority 1 (Critical - Fix Immediately)
| Issue | Impact | Recommendation | Owner | Due Date |
|-------|--------|----------------|-------|----------|
| | | | | |

### Priority 2 (Important - Fix Within 1 Week)
| Issue | Impact | Recommendation | Owner | Due Date |
|-------|--------|----------------|-------|----------|
| | | | | |

### Priority 3 (Nice to Have - Fix Within 1 Month)
| Issue | Impact | Recommendation | Owner | Due Date |
|-------|--------|----------------|-------|----------|
| | | | | |

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| | | | |

## Next Steps
-

## Follow-up Meeting
Date:
Agenda:
```

---

## 📚 Quick Reference Commands

### **Pre-Meeting Validation (All Platforms)**

```bash
# Set context
export NAMESPACE=redis-enterprise

# Quick health check
kubectl get nodes
kubectl get pods -n $NAMESPACE
kubectl get rec -n $NAMESPACE
kubectl get redb -n $NAMESPACE

# Check versions
kubectl get rec -n $NAMESPACE -o jsonpath='{.items[0].status.version}'
kubectl get deployment redis-enterprise-operator -n $NAMESPACE \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

### **During Meeting - Quick Checks (All Platforms)**

```bash
# Architecture
echo "REC Nodes: $(kubectl get rec -n $NAMESPACE -o jsonpath='{.items[0].spec.nodes}')"
kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o wide

# Storage
kubectl get pvc -n $NAMESPACE
kubectl get sc

# QoS
kubectl get pod rec-0 -n $NAMESPACE -o jsonpath='{.status.qosClass}'
echo ""

# Security
kubectl get networkpolicy -n $NAMESPACE
kubectl get redb -n $NAMESPACE -o jsonpath='{.items[0].spec.tlsMode}'
echo ""

# Monitoring
kubectl get servicemonitor -n $NAMESPACE 2>/dev/null || echo "ServiceMonitor not found"
kubectl get prometheusrule -n $NAMESPACE 2>/dev/null || echo "PrometheusRule not found"
```

---

### **Platform-Specific Commands**

**AWS EKS:**
```bash
aws eks describe-cluster --name <cluster> --region <region>
aws eks list-nodegroups --cluster-name <cluster> --region <region>
kubectl get pods -n kube-system | grep ebs-csi
```

**Google GKE:**
```bash
gcloud container clusters describe <cluster> --region <region>
gcloud container node-pools list --cluster <cluster> --region <region>
kubectl get pods -n kube-system | grep csi-gce-pd
```

**Azure AKS:**
```bash
az aks show -n <cluster> -g <resource-group>
az aks nodepool list -g <resource-group> --cluster-name <cluster>
kubectl get pods -n kube-system | grep csi-azuredisk
```

**OpenShift:**
```bash
oc version
oc get machineset -n openshift-machine-api
oc get csv -n redis-enterprise
```

**On-Premises:**
```bash
# Check Kubernetes distribution
kubectl version
kubectl get nodes -o wide

# Check storage backend
kubectl get storageclass
kubectl get sc <storage-class-name> -o jsonpath='{.provisioner}'

# VMware vSphere:
kubectl get pods -n vmware-system-csi

# Ceph (Rook):
kubectl get pods -n rook-ceph
kubectl get cephcluster -n rook-ceph

# Portworx:
kubectl get pods -n kube-system | grep portworx

# Check load balancer (MetalLB):
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
```

**Google Distributed Cloud (GDC):**
```bash
# Check GDC version
kubectl version
kubectl get nodes -o wide

# Check GDC-specific components
kubectl get pods -n gke-system

# Check if connected to Google Cloud
kubectl get pods -n gke-connect

# Check Workload Identity
kubectl get sa -n redis-enterprise -o yaml | grep iam.gke.io/gcp-service-account

# Check storage
kubectl get storageclass
```

---

## 🎯 Success Criteria

**By the end of the meeting, you should have:**

- [ ] Complete understanding of current architecture
- [ ] List of critical issues (if any) with severity
- [ ] Prioritized recommendations (P1/P2/P3)
- [ ] Action items with owners and due dates
- [ ] Follow-up meeting scheduled (if needed)
- [ ] Client buy-in on recommendations

**Client should have:**

- [ ] Confidence in their deployment (or clear path to improvement)
- [ ] Clear understanding of gaps and risks
- [ ] Actionable recommendations with priorities
- [ ] Timeline for improvements
- [ ] Contact for ongoing support

---

## 📞 Post-Meeting Follow-up

**Within 24 hours:**
- [ ] Send meeting notes (use template above)
- [ ] Send action items list with owners and due dates
- [ ] Share relevant documentation and guides

**Within 1 week:**
- [ ] Check on critical (P1) action items
- [ ] Provide additional support if needed
- [ ] Answer any follow-up questions

**Within 1 month:**
- [ ] Schedule follow-up review
- [ ] Validate improvements implemented
- [ ] Update recommendations based on progress

---

## 🔗 References

- [Best Practices README](README.md)
- [Validation Runbook](VALIDATION-RUNBOOK.md)
- **Platform-Specific Guides:**
  - [AWS EKS Guide](../platforms/eks/README.md)
  - [Google GKE Guide](../platforms/gke/README.md)
  - [Azure AKS Guide](../platforms/aks/README.md)
  - [OpenShift Guide](../platforms/openshift/README.md)
  - On-Premises: See storage and networking sections above
  - Google Distributed Cloud (GDC): See GDC section above
- **Security:**
  - [External Secrets for AWS](../security/external-secrets/aws/README.md)
  - [External Secrets for GCP](../security/external-secrets/gcp/README.md)
  - [External Secrets for Azure](../security/external-secrets/azure/README.md)
- **Backup/Restore:**
  - [S3 Backup Guide](../backup-restore/s3/README.md)
  - [GCS Backup Guide](../backup-restore/gcs/README.md)
  - [Azure Blob Backup Guide](../backup-restore/abs/README.md)

---

**Good luck with your meeting! 🚀**

**Remember:**
- Be consultative, not critical
- Focus on "opportunities for improvement" vs "problems"
- Prioritize recommendations (not everything is P1)
- Provide actionable next steps
- Offer ongoing support

