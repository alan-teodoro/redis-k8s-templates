# Node Management for Redis Enterprise on Kubernetes

Complete guide for managing Kubernetes nodes for Redis Enterprise deployments.

## 📋 Table of Contents

- [Node Selection](#node-selection)
- [Taints and Tolerations](#taints-and-tolerations)
- [Node Pools](#node-pools)
- [Quality of Service](#quality-of-service)
- [Eviction Thresholds](#eviction-thresholds)
- [Monitoring Node Conditions](#monitoring-node-conditions)
- [Resource Quotas](#resource-quotas)

---

## 🎯 Node Selection

### Using nodeSelector

**nodeSelector** is the simplest way to constrain pods to nodes with specific labels.

#### Step 1: Label Your Nodes

```bash
# Label nodes for high-memory workloads
kubectl label nodes node1 memory=high
kubectl label nodes node2 memory=high
kubectl label nodes node3 memory=high

# Verify labels
kubectl get nodes --show-labels | grep memory=high
```

#### Step 2: Configure REC with nodeSelector

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec
  namespace: redis-enterprise
spec:
  nodes: 3
  nodeSelector:
    memory: high
```

#### Step 3: Verify Pod Placement

```bash
# Check which nodes REC pods are running on
kubectl get pods -n redis-enterprise -o wide

# Verify node labels
kubectl get nodes -l memory=high
```

---

## 🏷️ Node Pools (Cloud Provider Specific)

### Google GKE

**Create node pool:**
```bash
gcloud container node-pools create redis-pool \
  --cluster=my-cluster \
  --machine-type=n2-highmem-8 \
  --num-nodes=3 \
  --node-labels=workload=redis
```

**Target node pool in REC:**
```yaml
spec:
  nodeSelector:
    cloud.google.com/gke-nodepool: redis-pool
```

### Azure AKS

**Create node pool:**
```bash
az aks nodepool add \
  --resource-group myResourceGroup \
  --cluster-name myAKSCluster \
  --name redispool \
  --node-count 3 \
  --node-vm-size Standard_E8s_v3 \
  --labels workload=redis
```

**Target node pool in REC:**
```yaml
spec:
  nodeSelector:
    agentpool: redispool
```

### AWS EKS

**Create node group:**
```bash
eksctl create nodegroup \
  --cluster=my-cluster \
  --name=redis-nodegroup \
  --node-type=r5.2xlarge \
  --nodes=3 \
  --node-labels="workload=redis"
```

**Target node group in REC:**
```yaml
spec:
  nodeSelector:
    eks.amazonaws.com/nodegroup: redis-nodegroup
```

---

## 🚫 Taints and Tolerations

### What are Taints?

**Taints** prevent pods from being scheduled on nodes unless they have matching **tolerations**.

**Use cases:**
- Reserve nodes exclusively for Redis Enterprise
- Separate production from development workloads
- Isolate database workloads from application workloads

### Step 1: Taint Nodes

```bash
# Taint nodes to reserve for Redis Enterprise
kubectl taint nodes node1 db=redis:NoSchedule
kubectl taint nodes node2 db=redis:NoSchedule
kubectl taint nodes node3 db=redis:NoSchedule

# Verify taints
kubectl describe node node1 | grep Taints
```

### Step 2: Add Tolerations to REC

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec
  namespace: redis-enterprise
spec:
  nodes: 3
  podTolerations:
  - key: db
    operator: Equal
    value: redis
    effect: NoSchedule
```

### Step 3: Verify Only REC Pods Can Schedule

```bash
# Try to schedule a test pod (should fail)
kubectl run test-pod --image=nginx -n redis-enterprise

# Check pod status (should be Pending with taint error)
kubectl describe pod test-pod -n redis-enterprise

# REC pods should be Running
kubectl get pods -n redis-enterprise -l app=redis-enterprise
```

### Remove Taints

```bash
# Remove taint from node
kubectl taint nodes node1 db=redis:NoSchedule-
```

---

## 🎯 Combining nodeSelector + Tolerations

For **strict isolation**, combine both:

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec-isolated
  namespace: redis-enterprise
spec:
  nodes: 3
  
  # Target specific nodes
  nodeSelector:
    memory: high
  
  # Tolerate taints on those nodes
  podTolerations:
  - key: workload
    operator: Equal
    value: redis-enterprise
    effect: NoSchedule
```

**Setup:**
```bash
# 1. Label high-memory nodes
kubectl label nodes node1 node2 node3 memory=high

# 2. Taint high-memory nodes
kubectl taint nodes node1 node2 node3 workload=redis-enterprise:NoSchedule

# 3. Apply REC
kubectl apply -f rec-isolated.yaml
```

---

## ⭐ Quality of Service (QoS)

### QoS Classes

Kubernetes assigns one of three QoS classes to pods:

| Class | Requirements | Eviction Priority |
|-------|--------------|-------------------|
| **Guaranteed** | limits = requests for CPU and memory | Lowest (last to evict) |
| **Burstable** | requests < limits | Medium |
| **Best Effort** | No requests or limits | Highest (first to evict) |

### Ensuring Guaranteed QoS for REC

**Requirements:**
1. Every container must have memory limit = memory request
2. Every container must have CPU limit = CPU request

**REC Configuration:**
```yaml
spec:
  redisEnterpriseNodeResources:
    limits:
      cpu: "4000m"
      memory: 15Gi
    requests:
      cpu: "4000m"      # Must equal limits
      memory: 15Gi      # Must equal limits
```

### Verify QoS Class

```bash
# Check QoS class of REC pod
kubectl get pod rec-0 -n redis-enterprise -o jsonpath="{.status.qosClass}"

# Expected output: Guaranteed
```

### Impact of Sidecar Containers

**⚠️ IMPORTANT:** Sidecar containers also impact QoS class.

If you add sidecars (e.g., log forwarders, monitoring agents), ensure they also have limits = requests:

```yaml
spec:
  sideContainersSpec:
  - name: log-forwarder
    image: fluent/fluent-bit:latest
    resources:
      limits:
        cpu: "100m"
        memory: 128Mi
      requests:
        cpu: "100m"      # Must equal limits
        memory: 128Mi    # Must equal limits
```

---

## 🚨 Eviction Thresholds

### What are Eviction Thresholds?

Kubernetes evicts pods when node resources (memory, disk) are low. Eviction thresholds control when this happens.

**Two types:**
- **Hard eviction** - Immediate pod termination when threshold is met
- **Soft eviction** - Grace period before termination

### Recommended Settings for Redis Enterprise

**✅ DO:**
- Set **soft eviction threshold HIGHER** than hard eviction threshold
- Set **eviction-soft-grace-period** high enough for administrator to scale cluster
- Set **eviction-max-pod-grace-period** high enough for Redis to migrate databases

**Why?**
- High soft threshold triggers node condition change early (alerts administrator)
- Grace period allows time to scale Kubernetes cluster before pods are killed
- Max pod grace period allows Redis to gracefully migrate databases

### Platform-Specific Configuration

#### OpenShift

Edit the KubeletConfig:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: redis-kubelet-config
spec:
  kubeletConfig:
    # Soft eviction thresholds (triggers early warning)
    evictionSoft:
      memory.available: "1.5Gi"
      nodefs.available: "15%"

    # Soft eviction grace periods (time to react)
    evictionSoftGracePeriod:
      memory.available: "2m"
      nodefs.available: "2m"

    # Hard eviction thresholds (immediate termination)
    evictionHard:
      memory.available: "1Gi"
      nodefs.available: "10%"

    # Max grace period for pod termination
    evictionMaxPodGracePeriod: 120
```

Apply:
```bash
kubectl apply -f kubelet-config.yaml
```

#### GKE

GKE manages eviction thresholds automatically, but you can customize:

**Option 1: Using GKE node pool settings**
```bash
gcloud container node-pools create redis-pool \
  --cluster=my-cluster \
  --machine-type=n2-highmem-8 \
  --num-nodes=3 \
  --system-config-from-file=system-config.yaml
```

**system-config.yaml:**
```yaml
kubeletConfig:
  cpuManagerPolicy: static
  evictionHard:
    memory.available: "1Gi"
```

**Option 2: Using GKE Autopilot** (managed automatically)

#### EKS

EKS uses kubelet configuration via user data or launch templates:

**Option 1: Using eksctl**
```yaml
# cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: my-cluster
  region: us-east-1

nodeGroups:
  - name: redis-nodes
    instanceType: r5.2xlarge
    desiredCapacity: 3
    kubeletExtraConfig:
      evictionHard:
        memory.available: "1Gi"
        nodefs.available: "10%"
      evictionSoft:
        memory.available: "1.5Gi"
        nodefs.available: "15%"
      evictionSoftGracePeriod:
        memory.available: "2m"
        nodefs.available: "2m"
      evictionMaxPodGracePeriod: 120
```

**Option 2: Using launch template user data**
```bash
#!/bin/bash
/etc/eks/bootstrap.sh my-cluster \
  --kubelet-extra-args '--eviction-hard=memory.available<1Gi,nodefs.available<10% \
  --eviction-soft=memory.available<1.5Gi,nodefs.available<15% \
  --eviction-soft-grace-period=memory.available=2m,nodefs.available=2m \
  --eviction-max-pod-grace-period=120'
```

### Verify Eviction Settings

```bash
# SSH into node and check kubelet config
kubectl debug node/node1 -it --image=ubuntu

# Inside debug pod
cat /var/lib/kubelet/config.yaml | grep -A 10 eviction
```

---

## 📊 Monitoring Node Conditions

### Critical Node Conditions

Monitor these conditions to detect eviction risk:

| Condition | Meaning | Action |
|-----------|---------|--------|
| **MemoryPressure** | Node memory is low | Scale cluster or reduce workload |
| **DiskPressure** | Node disk is low | Clean up disk or add storage |
| **PIDPressure** | Too many processes | Reduce pod count |
| **Ready** | Node is healthy | No action needed |

### Check Node Conditions

```bash
# Check all node conditions
kubectl get nodes -o jsonpath='{range .items[*]}name:{.metadata.name}{"\t"}MemoryPressure:{.status.conditions[?(@.type == "MemoryPressure")].status}{"\t"}DiskPressure:{.status.conditions[?(@.type == "DiskPressure")].status}{"\n"}{end}'

# Expected output (healthy):
# name:node1	MemoryPressure:False	DiskPressure:False
# name:node2	MemoryPressure:False	DiskPressure:False
# name:node3	MemoryPressure:False	DiskPressure:False
```

### Continuous Monitoring with Prometheus

Add this PrometheusRule to alert on node pressure:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-pressure-alerts
  namespace: monitoring
spec:
  groups:
  - name: node-pressure
    interval: 30s
    rules:
    - alert: NodeMemoryPressure
      expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Node {{ $labels.node }} has memory pressure"
        description: "Node {{ $labels.node }} is experiencing memory pressure. Consider scaling the cluster."

    - alert: NodeDiskPressure
      expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Node {{ $labels.node }} has disk pressure"
        description: "Node {{ $labels.node }} is experiencing disk pressure. Clean up disk or add storage."
```

### Watch Node Conditions in Real-Time

```bash
# Watch node conditions continuously
watch -n 5 'kubectl get nodes -o custom-columns="NAME:.metadata.name,MEMORY:.status.conditions[?(@.type==\"MemoryPressure\")].status,DISK:.status.conditions[?(@.type==\"DiskPressure\")].status"'
```

---

## 📦 Resource Quotas

### What are Resource Quotas?

**ResourceQuota** limits resource consumption per namespace.

**Use cases:**
- Prevent runaway resource consumption
- Enforce resource limits per environment (dev/test/prod)
- Multi-tenancy isolation

### Example: Resource Quota for Redis Enterprise Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: redis-enterprise-quota
  namespace: redis-enterprise
spec:
  hard:
    # Limit total CPU requests
    requests.cpu: "24"

    # Limit total memory requests
    requests.memory: 96Gi

    # Limit total CPU limits
    limits.cpu: "24"

    # Limit total memory limits
    limits.memory: 96Gi

    # Limit number of pods
    pods: "10"

    # Limit number of PVCs
    persistentvolumeclaims: "10"

    # Limit total storage requests
    requests.storage: 500Gi
```

**This quota allows:**
- 3 REC pods (8 CPU, 30GB each) = 24 CPU, 90GB
- 3 databases
- 3 PVCs for REC + some for databases
- Total storage: 500GB

### Apply Resource Quota

```bash
kubectl apply -f resource-quota.yaml
```

### Verify Resource Quota

```bash
# Check quota status
kubectl describe resourcequota redis-enterprise-quota -n redis-enterprise

# Output shows used vs hard limits:
# Name:                   redis-enterprise-quota
# Namespace:              redis-enterprise
# Resource                Used   Hard
# --------                ----   ----
# limits.cpu              24     24
# limits.memory           90Gi   96Gi
# persistentvolumeclaims  3      10
# pods                    3      10
# requests.cpu            24     24
# requests.memory         90Gi   96Gi
# requests.storage        300Gi  500Gi
```

### Operator Minimum Resources

The Redis Enterprise Operator requires minimum resources:

```yaml
# Operator deployment
resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 500m
    memory: 256Mi
```

**Include this in your ResourceQuota calculations.**

---

## 📊 Next Steps

1. **Choose node selection strategy** (nodeSelector, taints, or both)
2. **Label and taint nodes** appropriately
3. **Configure REC** with nodeSelector and/or tolerations
4. **Verify QoS class** is Guaranteed
5. **Configure eviction thresholds** for your platform
6. **Setup monitoring** for node conditions
7. **Apply resource quotas** to prevent runaway consumption

---

## 📚 Related Documentation

- [Node Selection Examples](../../deployments/single-region/06-node-selection.yaml)
- [Priority Class](../../deployments/single-region/03-priority-class.yaml)
- [Best Practices](../../best-practices/README.md)
- [HA & Disaster Recovery](../ha-disaster-recovery/README.md)
- [Monitoring](../../monitoring/README.md)

