# Best Practices Validation Runbook

This runbook provides step-by-step commands to **test, validate, confirm, and calculate** each best practice for Redis Enterprise on Kubernetes.

---

## 📋 Table of Contents

1. [Architecture Validation](#1-architecture-validation)
2. [Storage Validation](#2-storage-validation)
3. [Node Management Validation](#3-node-management-validation)
4. [Quality of Service Validation](#4-quality-of-service-validation)
5. [Eviction Thresholds Validation](#5-eviction-thresholds-validation)
6. [Resource Quotas Validation](#6-resource-quotas-validation)
7. [Rack-Zone Awareness Validation](#7-rack-zone-awareness-validation)
8. [Security Validation](#8-security-validation)
9. [High Availability Validation](#9-high-availability-validation)
10. [Monitoring Validation](#10-monitoring-validation)

---

## 1. Architecture Validation

### ✅ **Validate Minimum 3 Nodes**

**Why:** Ensures quorum for cluster consensus and high availability.

**Test:**
```bash
# Get number of REC nodes
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}'

# Expected: >= 3
```

**Validation:**
```bash
# Verify all pods are running
kubectl get pods -n redis-enterprise -l app=redis-enterprise

# Expected: 3 or more pods in Running state
```

**Why it matters:**
- 2 nodes = no quorum (cluster fails if 1 node down)
- 3 nodes = quorum maintained with 1 node down
- 5 nodes = quorum maintained with 2 nodes down

---

### ✅ **Validate Pod Anti-Affinity**

**Why:** Prevents multiple REC pods from running on the same Kubernetes node.

**Test:**
```bash
# Check pod anti-affinity rules
kubectl get rec -n redis-enterprise -o yaml | grep -A20 podAntiAffinity

# Expected: requiredDuringSchedulingIgnoredDuringExecution with topologyKey: kubernetes.io/hostname
```

**Validation:**
```bash
# Verify pods are on different nodes
kubectl get pods -n redis-enterprise -l app=redis-enterprise -o wide

# Expected: Each pod on different NODE
```

**Calculate:**
```bash
# Count unique nodes
UNIQUE_NODES=$(kubectl get pods -n redis-enterprise -l app=redis-enterprise -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
TOTAL_PODS=$(kubectl get pods -n redis-enterprise -l app=redis-enterprise --no-headers | wc -l)

echo "Unique nodes: $UNIQUE_NODES"
echo "Total pods: $TOTAL_PODS"

# Expected: UNIQUE_NODES == TOTAL_PODS
```

**Why it matters:**
- Prevents single node failure from taking down multiple REC pods
- Ensures cluster resilience

---

### ✅ **Validate Spare Kubernetes Nodes**

**Why:** Ensures REC pods can be rescheduled when a node fails.

**Test:**
```bash
# Count total worker nodes
TOTAL_NODES=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/master,!node-role.kubernetes.io/control-plane' | wc -l)

# Count REC pods
REC_PODS=$(kubectl get pods -n redis-enterprise -l app=redis-enterprise --no-headers | wc -l)

echo "Total worker nodes: $TOTAL_NODES"
echo "REC pods: $REC_PODS"
echo "Spare nodes: $((TOTAL_NODES - REC_PODS))"

# Expected: Spare nodes >= 1 (preferably 1 per AZ)
```

**Why it matters:**
- Without spare nodes, pod cannot be rescheduled if node fails
- Cluster becomes degraded until new node is added

---

### ✅ **Validate Multi-AZ Deployment**

**Why:** Ensures cluster survives availability zone failures.

**Test:**
```bash
# Check pod distribution across zones
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:metadata.name,NODE:spec.nodeName,ZONE:spec.nodeSelector.topology\.kubernetes\.io/zone"

# Or check node zones
kubectl get nodes -o custom-columns="NODE:metadata.name,ZONE:metadata.labels.topology\.kubernetes\.io/zone"
```

**Validation:**
```bash
# Count unique zones
UNIQUE_ZONES=$(kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o jsonpath='{range .items[*]}{.spec.nodeSelector.topology\.kubernetes\.io/zone}{"\n"}{end}' \
  | sort -u | wc -l)

echo "Pods distributed across $UNIQUE_ZONES zones"

# Expected: >= 2 zones (preferably 3)
```

**Why it matters:**
- Single zone failure doesn't take down entire cluster
- Meets high availability requirements

---

## 2. Storage Validation

### ✅ **Validate Block Storage (Not NFS)**

**Why:** NFS causes locking issues and poor performance for databases.

**Test:**
```bash
# Get storage class used by REC
STORAGE_CLASS=$(kubectl get pvc -n redis-enterprise -l app=redis-enterprise \
  -o jsonpath='{.items[0].spec.storageClassName}')

echo "Storage class: $STORAGE_CLASS"

# Get storage class details
kubectl get storageclass $STORAGE_CLASS -o yaml
```

**Validation:**
```bash
# Check provisioner (should be block storage)
kubectl get storageclass $STORAGE_CLASS -o jsonpath='{.provisioner}'

# Expected provisioners:
# - AWS: ebs.csi.aws.com (EBS)
# - GCP: pd.csi.storage.gke.io (Persistent Disk)
# - Azure: disk.csi.azure.com (Managed Disk)
# - NOT: nfs.csi.k8s.io or similar
```

**Why it matters:**
- NFS has locking behavior incompatible with Redis Enterprise
- Block storage provides required performance and consistency

---

### ✅ **Validate Volume Size (5x Memory)**

**Why:** Redis Enterprise requires 5x memory for persistence (snapshots, AOF, temp files).

**Calculate:**
```bash
# Get REC memory per node
MEMORY_PER_NODE=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}')

echo "Memory per node: $MEMORY_PER_NODE"

# Convert to GB (if in Gi)
MEMORY_GB=$(echo $MEMORY_PER_NODE | sed 's/Gi//')

# Calculate recommended volume size
RECOMMENDED_VOLUME=$((MEMORY_GB * 5))

echo "Recommended volume size: ${RECOMMENDED_VOLUME}Gi"
```

**Validation:**
```bash
# Get actual PVC size
kubectl get pvc -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="NAME:metadata.name,SIZE:spec.resources.requests.storage"

# Compare with recommended size
```

**Example:**
- Memory: 15Gi → Volume: 75Gi (5x)
- Memory: 30Gi → Volume: 150Gi (5x)

**Why it matters:**
- Insufficient storage causes database failures
- 5x ratio accounts for snapshots, AOF files, and temporary files

---

### ✅ **Validate Storage Class Expansion**

**Why:** Allows PVC expansion without recreating cluster.

**Test:**
```bash
# Check if storage class allows expansion
STORAGE_CLASS=$(kubectl get pvc -n redis-enterprise -l app=redis-enterprise \
  -o jsonpath='{.items[0].spec.storageClassName}')

kubectl get storageclass $STORAGE_CLASS -o jsonpath='{.allowVolumeExpansion}'

# Expected: true
```

**Why it matters:**
- Without expansion support, you must recreate cluster to increase storage
- Causes downtime and complexity

---

## 3. Node Management Validation

### ✅ **Validate Node Selector**

**Why:** Ensures REC pods run on appropriate nodes (e.g., high-memory nodes).

**Test:**
```bash
# Check if nodeSelector is configured
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodeSelector}'

# Example output: {"memory":"high"} or {"cloud.google.com/gke-nodepool":"redis-pool"}
```

**Validation:**
```bash
# Verify nodes have matching labels
kubectl get nodes -l memory=high  # Replace with your label

# Verify REC pods are on labeled nodes
kubectl get pods -n redis-enterprise -l app=redis-enterprise -o wide
```

**Why it matters:**
- Prevents REC pods from running on undersized nodes
- Ensures consistent performance

---

### ✅ **Validate Node Taints and Tolerations**

**Why:** Reserves nodes exclusively for Redis Enterprise.

**Test:**
```bash
# Check node taints
kubectl get nodes -o custom-columns="NODE:metadata.name,TAINTS:spec.taints[*].key"

# Check REC tolerations
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.podTolerations}'
```

**Validation:**
```bash
# Example: Verify taint exists
kubectl describe node <node-name> | grep Taints

# Expected: db=rec:NoSchedule (or similar)

# Verify REC has matching toleration
kubectl get rec -n redis-enterprise -o yaml | grep -A5 podTolerations
```

**Why it matters:**
- Prevents other workloads from consuming resources on Redis nodes
- Ensures dedicated resources for Redis Enterprise

---

## 4. Quality of Service Validation

### ✅ **Validate Guaranteed QoS**

**Why:** Prevents pod eviction under resource pressure.

**Test:**
```bash
# Check QoS class of REC pods
kubectl get pod -n redis-enterprise rec-0 -o jsonpath='{.status.qosClass}'

# Expected: Guaranteed
```

**Validation:**
```bash
# Verify limits == requests for all containers
kubectl get pod -n redis-enterprise rec-0 -o json | jq '.spec.containers[] | {name: .name, requests: .resources.requests, limits: .resources.limits}'

# Expected: For each container, limits.cpu == requests.cpu AND limits.memory == requests.memory
```

**Calculate:**
```bash
# Check if limits == requests
kubectl get rec -n redis-enterprise -o yaml | grep -A10 redisEnterpriseNodeResources

# Example:
# limits:
#   cpu: "4000m"
#   memory: 15Gi
# requests:
#   cpu: "4000m"    # ✅ Same as limits
#   memory: 15Gi    # ✅ Same as limits
```

**Why it matters:**
- **Guaranteed QoS**: Pod is never evicted due to resource pressure
- **Burstable QoS**: Pod may be evicted if node is under pressure
- **Best Effort QoS**: Pod is evicted first

---

### ✅ **Validate PriorityClass**

**Why:** Prevents preemption by lower-priority workloads.

**Test:**
```bash
# Check if PriorityClass is set
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.priorityClassName}'

# Check PriorityClass value
kubectl get priorityclass redis-enterprise-priority -o jsonpath='{.value}'

# Expected: High value (e.g., 1000000000)
```

**Validation:**
```bash
# Verify REC pods have priority
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:metadata.name,PRIORITY:spec.priority"
```

**Why it matters:**
- High priority prevents Kubernetes from preempting REC pods
- Ensures cluster stability during resource contention

---

## 5. Eviction Thresholds Validation

### ✅ **Monitor Node Conditions**

**Why:** Detects when nodes are under memory or disk pressure.

**Test:**
```bash
# Check node conditions
kubectl get nodes -o jsonpath='{range .items[*]}name:{.metadata.name}{"\t"}MemoryPressure:{.status.conditions[?(@.type == "MemoryPressure")].status}{"\t"}DiskPressure:{.status.conditions[?(@.type == "DiskPressure")].status}{"\n"}{end}'

# Expected: MemoryPressure:False, DiskPressure:False
```

**Validation:**
```bash
# Check specific node
kubectl describe node <node-name> | grep -A5 Conditions

# Look for:
# MemoryPressure   False
# DiskPressure     False
```

**Why it matters:**
- **MemoryPressure=True**: Node is running out of memory, pods may be evicted
- **DiskPressure=True**: Node is running out of disk, pods may be evicted
- Both True = eviction threshold met

---

### ✅ **Validate Eviction Threshold Configuration**

**Why:** Ensures proper grace periods for Redis to migrate data before eviction.

**Test (varies by platform):**

**For all platforms:**
```bash
# Check kubelet config (if accessible)
kubectl get --raw /api/v1/nodes/<node-name>/proxy/configz | jq '.kubeletconfig.evictionHard'
```

**Recommended values:**
```yaml
evictionHard:
  memory.available: "500Mi"
  nodefs.available: "10%"
evictionSoft:
  memory.available: "1Gi"
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "5m"
  nodefs.available: "5m"
evictionMaxPodGracePeriod: "10m"
```

**Why it matters:**
- **Soft > Hard**: Gives early warning before hard eviction
- **Grace periods**: Allow time for admin to scale or Redis to migrate
- **Max pod grace period**: Prevents forced termination during migration

---

## 6. Resource Quotas Validation

### ✅ **Calculate Required Resource Quota**

**Why:** Prevents resource exhaustion and ensures capacity for REC.

**Calculate:**
```bash
# Get REC configuration
NODES=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.nodes}')
CPU_PER_NODE=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.cpu}')
MEMORY_PER_NODE=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.redisEnterpriseNodeResources.limits.memory}')

echo "REC Configuration:"
echo "  Nodes: $NODES"
echo "  CPU per node: $CPU_PER_NODE"
echo "  Memory per node: $MEMORY_PER_NODE"

# Convert CPU to millicores (if needed)
CPU_MILLICORES=$(echo $CPU_PER_NODE | sed 's/m//')

# Convert memory to Mi (if in Gi)
MEMORY_MI=$(echo $MEMORY_PER_NODE | sed 's/Gi/*1024/' | bc)

# Calculate REC total
REC_TOTAL_CPU=$((CPU_MILLICORES * NODES))
REC_TOTAL_MEMORY=$((MEMORY_MI * NODES))

# Add operator minimum
OPERATOR_CPU=500
OPERATOR_MEMORY=256

# Calculate subtotal
SUBTOTAL_CPU=$((REC_TOTAL_CPU + OPERATOR_CPU))
SUBTOTAL_MEMORY=$((REC_TOTAL_MEMORY + OPERATOR_MEMORY))

# Add 20% buffer
BUFFER_CPU=$((SUBTOTAL_CPU * 20 / 100))
BUFFER_MEMORY=$((SUBTOTAL_MEMORY * 20 / 100))

# Calculate total quota
TOTAL_CPU=$((SUBTOTAL_CPU + BUFFER_CPU))
TOTAL_MEMORY=$((SUBTOTAL_MEMORY + BUFFER_MEMORY))

echo ""
echo "Resource Quota Calculation:"
echo "  REC: ${REC_TOTAL_CPU}m CPU, ${REC_TOTAL_MEMORY}Mi memory"
echo "  Operator: ${OPERATOR_CPU}m CPU, ${OPERATOR_MEMORY}Mi memory"
echo "  Buffer (20%): ${BUFFER_CPU}m CPU, ${BUFFER_MEMORY}Mi memory"
echo "  ----------------------------------------"
echo "  TOTAL QUOTA: ${TOTAL_CPU}m CPU, ${TOTAL_MEMORY}Mi memory"
```

**Example:**
```
REC: 3 nodes × 4000m CPU × 15Gi memory
  = 12000m CPU + 45Gi (46080Mi) memory
Operator: 500m CPU + 256Mi memory
Buffer (20%): 2500m CPU + 9267Mi memory
----------------------------------------
TOTAL: 15000m CPU + 55603Mi (~54Gi) memory
```

**Validation:**
```bash
# Check current quota
kubectl get resourcequota -n redis-enterprise

# Get quota details
kubectl describe resourcequota -n redis-enterprise
```

**Why it matters:**
- Prevents other workloads from starving REC
- Ensures capacity for scaling
- Prevents cluster degradation

---

### ✅ **Validate Operator Minimum Resources**

**Why:** Operator needs minimum resources to function properly.

**Test:**
```bash
# Check operator resources
kubectl get deployment redis-enterprise-operator -n redis-enterprise \
  -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Expected minimum:
# limits:
#   cpu: 500m
#   memory: 256Mi
# requests:
#   cpu: 500m
#   memory: 256Mi
```

**Why it matters:**
- Insufficient operator resources cause reconciliation failures
- Operator manages cluster lifecycle

---

## 7. Rack-Zone Awareness Validation

### ✅ **Validate Node Labels**

**Why:** All eligible nodes must have topology label for rack awareness.

**Test:**
```bash
# Check if rack awareness is enabled
kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.rackAwarenessNodeLabel}'

# Expected: topology.kubernetes.io/zone (or custom label)
```

**Validation:**
```bash
# Get label from REC
RACK_LABEL=$(kubectl get rec -n redis-enterprise -o jsonpath='{.items[0].spec.rackAwarenessNodeLabel}')

# Check all nodes have the label
kubectl get nodes -o custom-columns="NODE:metadata.name,ZONE:metadata.labels.$RACK_LABEL"

# Expected: All nodes have a value (no <none>)
```

**Calculate:**
```bash
# Count nodes without label
NODES_WITHOUT_LABEL=$(kubectl get nodes -o json | jq -r ".items[] | select(.metadata.labels[\"$RACK_LABEL\"] == null) | .metadata.name")

if [ -z "$NODES_WITHOUT_LABEL" ]; then
  echo "✅ All nodes have rack-zone label"
else
  echo "❌ Nodes without label:"
  echo "$NODES_WITHOUT_LABEL"
fi
```

**Why it matters:**
- Missing labels cause reconciliation failure
- Rack awareness requires ALL eligible nodes to be labeled

---

### ✅ **Validate ClusterRole for Rack Awareness**

**Why:** Operator needs permission to read node labels.

**Test:**
```bash
# Check ClusterRole
kubectl get clusterrole redis-enterprise-operator -o yaml | grep -A5 "resources.*nodes"

# Expected:
# - apiGroups: [""]
#   resources: ["nodes"]
#   verbs: ["list", "get", "watch"]
```

**Validation:**
```bash
# Check ClusterRoleBinding
kubectl get clusterrolebinding redis-enterprise-operator -o yaml

# Verify it binds to redis-enterprise-operator service account
```

**Why it matters:**
- Without permissions, operator cannot read node topology
- Rack awareness fails silently

---

### ⚠️ **Validate Rack Distribution (Manual Check)**

**Why:** Pod restarts may violate rack distribution.

**Test:**
```bash
# Check current pod distribution
kubectl get pods -n redis-enterprise -l app=redis-enterprise \
  -o custom-columns="POD:metadata.name,NODE:spec.nodeName,ZONE:spec.nodeSelector.topology\.kubernetes\.io/zone"

# Check shard distribution (via REC API)
kubectl exec -it rec-0 -n redis-enterprise -- \
  curl -k -u admin@redis.com:password \
  https://localhost:9443/v1/shards | jq '.[] | {uid, node_uid, role}'
```

**Why it matters:**
- **CRITICAL LIMITATION**: Rack distribution is NOT maintained after pod restarts
- Manual intervention required to restore proper distribution
- Important for edge deployments

---

## 8. Security Validation

### ✅ **Validate TLS Enabled**

**Why:** Encrypts data in transit.

**Test:**
```bash
# Check if TLS is enabled on database
kubectl get redb -n redis-enterprise -o jsonpath='{.items[0].spec.tlsMode}'

# Expected: enabled or replica_ssl
```

**Validation:**
```bash
# Test connection with TLS
redis-cli -h <db-host> -p <db-port> --tls --insecure PING

# Expected: PONG
```

**Why it matters:**
- Unencrypted connections expose data
- Compliance requirements

---

### ✅ **Validate Network Policies**

**Why:** Restricts traffic to/from Redis Enterprise.

**Test:**
```bash
# Check if network policies exist
kubectl get networkpolicy -n redis-enterprise

# Expected: At least deny-all and allow-redis-enterprise
```

**Validation:**
```bash
# Test blocked connection (from different namespace)
kubectl run test-blocked -n default --image=redis:latest --rm -it -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 12000 PING

# Expected: Timeout (connection blocked)
```

**Why it matters:**
- Prevents unauthorized access
- Limits blast radius of compromised pods

---

### ✅ **Validate Pod Security Standards**

**Why:** Enforces security best practices.

**Test:**
```bash
# Check namespace labels
kubectl get namespace redis-enterprise --show-labels | grep pod-security

# Expected: pod-security.kubernetes.io/enforce=restricted (or baseline)
```

**Validation:**
```bash
# Try to create privileged pod (should fail)
kubectl run test-privileged -n redis-enterprise --image=redis:latest --privileged=true

# Expected: Error (blocked by PSS)
```

**Why it matters:**
- Prevents privilege escalation
- Enforces least privilege

---

## 9. High Availability Validation

### ✅ **Validate Database Replication**

**Why:** Ensures data survives pod failures.

**Test:**
```bash
# Check replication status
kubectl get redb -n redis-enterprise -o jsonpath='{.items[0].spec.replication}'

# Expected: true
```

**Validation:**
```bash
# Check shard count (should be 2x for replication)
kubectl exec -it rec-0 -n redis-enterprise -- \
  curl -k -u admin@redis.com:password \
  https://localhost:9443/v1/bdbs/1 | jq '.shards_count'

# For replicated DB: shards_count = 2 × number of shards
```

**Why it matters:**
- Without replication, pod failure causes data loss
- Replication provides high availability

---

### ✅ **Validate Pod Disruption Budget**

**Why:** Prevents too many pods from being disrupted simultaneously.

**Test:**
```bash
# Check PDB
kubectl get pdb -n redis-enterprise

# Get PDB details
kubectl describe pdb -n redis-enterprise
```

**Validation:**
```bash
# Check min available
kubectl get pdb -n redis-enterprise -o jsonpath='{.items[0].spec.minAvailable}'

# Expected: 2 (for 3-node cluster) - maintains quorum
```

**Why it matters:**
- Prevents cluster quorum loss during maintenance
- Ensures minimum availability

---

## 10. Monitoring Validation

### ✅ **Validate Prometheus Metrics**

**Why:** Enables monitoring and alerting.

**Test:**
```bash
# Check if ServiceMonitor exists
kubectl get servicemonitor -n redis-enterprise

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Query metrics
curl http://localhost:9090/api/v1/query?query=redis_up

# Expected: {"status":"success", "data":{"result":[...]}}
```

**Why it matters:**
- Without metrics, you're flying blind
- Enables proactive issue detection

---

### ✅ **Validate Alerting Rules**

**Why:** Notifies on critical issues.

**Test:**
```bash
# Check PrometheusRule
kubectl get prometheusrule -n redis-enterprise

# Get rule details
kubectl get prometheusrule -n redis-enterprise -o yaml | grep -A10 "alert:"
```

**Why it matters:**
- Alerts enable rapid response
- Prevents prolonged outages

---

## 📊 Summary Checklist

Use this checklist to validate all best practices:

### Architecture
- [ ] Minimum 3 nodes
- [ ] Pod anti-affinity enabled
- [ ] Spare Kubernetes nodes available
- [ ] Multi-AZ deployment

### Storage
- [ ] Block storage (not NFS)
- [ ] Volume size = 5x memory
- [ ] Storage class allows expansion

### Node Management
- [ ] Node selector configured (if needed)
- [ ] Taints and tolerations configured (if needed)

### Quality of Service
- [ ] Guaranteed QoS (limits = requests)
- [ ] PriorityClass configured

### Eviction Thresholds
- [ ] Node conditions monitored
- [ ] Soft > Hard thresholds
- [ ] Grace periods configured

### Resource Quotas
- [ ] Quota calculated correctly
- [ ] Operator minimum resources met

### Rack-Zone Awareness
- [ ] All nodes labeled
- [ ] ClusterRole configured
- [ ] Rack distribution validated

### Security
- [ ] TLS enabled
- [ ] Network policies configured
- [ ] Pod Security Standards enforced

### High Availability
- [ ] Database replication enabled
- [ ] Pod Disruption Budget configured

### Monitoring
- [ ] Prometheus metrics available
- [ ] Alerting rules configured

---

## 🔗 References

- [Best Practices README](README.md)
- [Capacity Planning](../operations/capacity-planning/README.md)
- [Official Redis Enterprise Documentation](https://redis.io/docs/latest/operate/kubernetes/)

