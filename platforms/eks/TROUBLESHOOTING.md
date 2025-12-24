# EKS Troubleshooting Guide

Common issues and solutions when deploying Redis Enterprise on Amazon EKS.

---

## Table of Contents

- [Operator Installation Issues](#operator-installation-issues)
- [REC Deployment Issues](#rec-deployment-issues)
- [Resource Issues](#resource-issues)
- [Storage Issues](#storage-issues)
- [Networking Issues](#networking-issues)

---

## Operator Installation Issues

### Helm Chart Not Found

**Symptom:**
```bash
helm search repo redis/redis-enterprise-operator
# No results found
```

**Cause:** Helm repository indexing issues with `https://helm.redis.io`

**Solution:** Install directly from the chart URL:

```bash
helm install redis-operator \
  https://github.com/RedisLabs/redis-enterprise-helm/releases/download/redis-enterprise-operator-8.0.6-8/redis-enterprise-operator-8.0.6-8.tgz \
  --namespace redis-enterprise
```

Check [Redis Enterprise releases](https://github.com/RedisLabs/redis-enterprise-helm/releases) for the latest version.

---

## REC Deployment Issues

### REC Pods Stuck in Pending - Insufficient Resources

**Symptom:**
```bash
kubectl get pods -n redis-enterprise
# rec-0   0/2   Pending   0   2m
```

**Error in describe:**
```
0/3 nodes are available: 3 Insufficient cpu, 3 Insufficient memory
```

**Cause:** REC resource requests exceed available node capacity.

**Solution:** Adjust `redisEnterpriseNodeResources` in your REC YAML to match your node size:

For **2 vCPU / 8Gi nodes**:
```yaml
redisEnterpriseNodeResources:
  limits:
    cpu: "1000m"
    memory: 4Gi
  requests:
    cpu: "1000m"
    memory: 4Gi
```

For **4 vCPU / 16Gi nodes**:
```yaml
redisEnterpriseNodeResources:
  limits:
    cpu: "2000m"
    memory: 8Gi
  requests:
    cpu: "2000m"
    memory: 8Gi
```

### Rack Awareness RBAC Error

**Symptom:** REC created but pods don't appear, operator logs show:

```
nodes is forbidden: User "system:serviceaccount:redis-enterprise:redis-enterprise-operator" 
cannot list resource "nodes" in API group ""
```

**Cause:** When using `rackAwarenessNodeLabel`, the operator needs permission to read node labels.

**Solution:** Apply the RBAC configuration:

```bash
kubectl apply -f rbac-rack-awareness.yaml
```

Or create manually:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: redis-enterprise-operator-nodes-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: redis-enterprise-operator-nodes-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: redis-enterprise-operator-nodes-reader
subjects:
  - kind: ServiceAccount
    name: redis-enterprise-operator
    namespace: redis-enterprise
```

### Services Rigger CrashLoopBackOff

**Symptom:**
```bash
kubectl get pods -n redis-enterprise
# rec-services-rigger-xxxxx   0/1   CrashLoopBackOff   4   2m
```

**Error in logs:**
```
Invalid service type: ClusterIP
```

**Cause:** Incorrect format for `databaseServiceType` in `servicesRiggerSpec`.

**Solution:** Use lowercase with underscore:

```yaml
servicesRiggerSpec:
  databaseServiceType: cluster_ip  # NOT "ClusterIP"
  serviceNaming: bdb_name
```

Valid values: `cluster_ip`, `headless`, `load_balancer`

---

## Resource Issues

### Check Node Resources

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

### Check Resource Allocation

```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Check Pod Resource Requests

```bash
kubectl describe pod rec-0 -n redis-enterprise | grep -A 10 "Requests:"
```

---

## Storage Issues

### PVC Stuck in Pending

**Check StorageClass:**
```bash
kubectl get storageclass
```

**Check PVC status:**
```bash
kubectl get pvc -n redis-enterprise
kubectl describe pvc <pvc-name> -n redis-enterprise
```

**Common causes:**
- EBS CSI driver not installed
- StorageClass doesn't exist
- Insufficient EBS volume quota in AWS account

**Verify EBS CSI driver:**
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

---

## Networking Issues

### Cannot Access UI

**Check UI service:**
```bash
kubectl get svc -n redis-enterprise
```

**For LoadBalancer access:**
```yaml
uiServiceType: LoadBalancer
```

**Get LoadBalancer URL:**
```bash
kubectl get svc rec-ui -n redis-enterprise
```

---

## Useful Debugging Commands

### Check operator logs
```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c redis-enterprise-operator --tail=100
```

### Check admission controller logs
```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=100
```

### Check REC status
```bash
kubectl get rec -n redis-enterprise
kubectl describe rec rec -n redis-enterprise
```

### Check all events
```bash
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'
```

### Check pod details
```bash
kubectl describe pod <pod-name> -n redis-enterprise
kubectl logs <pod-name> -n redis-enterprise
```

