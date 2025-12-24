# Basic Redis Enterprise Deployment

This directory contains cloud-agnostic configurations for deploying a basic Redis Enterprise cluster on Kubernetes.

## Overview

This deployment creates:
- ✅ **3-node Redis Enterprise cluster** with rack awareness
- ✅ **High availability** across availability zones
- ✅ **Persistent storage** using cluster default StorageClass
- ✅ **Test database** with replication
- ✅ **RBAC** for rack awareness (zone distribution)

---

## Files

- **`rec-basic.yaml`** - Redis Enterprise Cluster configuration
- **`redb-test.yaml`** - Test database configuration
- **`rbac-rack-awareness.yaml`** - RBAC for zone distribution

---

## Prerequisites

- Kubernetes cluster (1.23+)
- kubectl configured
- Cluster admin access
- Default StorageClass configured
- Redis Enterprise Operator installed

---

## Quick Start

### 1. Install Redis Enterprise Operator

```bash
helm repo add redis-enterprise https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/helm-releases
helm repo update

helm install redis-operator redis-enterprise/redis-enterprise-operator \
  --namespace redis-enterprise \
  --create-namespace
```

Or use direct URL method:

```bash
helm install redis-operator \
  https://github.com/RedisLabs/redis-enterprise-k8s-docs/raw/master/helm-releases/redis-enterprise-operator-8.0.6-8.tgz \
  --namespace redis-enterprise \
  --create-namespace
```

### 2. Apply RBAC for Rack Awareness

```bash
kubectl apply -f rbac-rack-awareness.yaml
```

### 3. Deploy Redis Enterprise Cluster

```bash
kubectl apply -f rec-basic.yaml
```

Wait for cluster to be ready (~3-5 minutes):

```bash
kubectl get rec -n redis-enterprise -w
```

### 4. Create Test Database

```bash
kubectl apply -f redb-test.yaml
```

### 5. Get Database Credentials

```bash
# Database password
kubectl get secret -n redis-enterprise redb-test-db -o jsonpath='{.data.password}' | base64 --decode
echo ""

# Database port
kubectl get redb -n redis-enterprise test-db -o jsonpath='{.status.databasePort}'
```

---

## Configuration

### Cluster Configuration (`rec-basic.yaml`)

Key settings:
- **Nodes:** 3 (for high availability)
- **Storage:** Uses cluster default StorageClass
- **Rack Awareness:** Distributes pods across zones using `topology.kubernetes.io/zone` label
- **Resources:** Adjust based on your node size (see comments in file)

### Database Configuration (`redb-test.yaml`)

Key settings:
- **Replication:** Enabled (2 shards)
- **Memory:** 100MB (for testing)
- **Eviction Policy:** volatile-lru

---

## Platform-Specific Guides

For platform-specific configurations and detailed guides:

- **[AWS EKS](../../platforms/eks/)** - gp3 StorageClass, EBS CSI driver, node sizing
- **[Google GKE](../../platforms/gke/)** - pd-ssd StorageClass, GCE persistent disks
- **[Azure AKS](../../platforms/aks/)** - managed-premium StorageClass, Azure disks

---

## Customization

### Adjust Node Resources

Edit `rec-basic.yaml` and modify `redisEnterpriseNodeResources`:

```yaml
redisEnterpriseNodeResources:
  limits:
    cpu: "2000m"      # Adjust based on node size
    memory: 8Gi       # Adjust based on node size
  requests:
    cpu: "2000m"
    memory: 8Gi
```

**Rule of thumb:** Use ~50% of node resources per REC pod.

### Use Specific StorageClass

If you don't want to use the default StorageClass, add to `rec-basic.yaml`:

```yaml
persistentSpec:
  enabled: true
  storageClassName: "your-storage-class"  # Specify your StorageClass
  volumeSize: "100Gi"
```

---

## Verification

### Check Cluster Status

```bash
kubectl get rec -n redis-enterprise
kubectl get pods -n redis-enterprise
```

### Check Database Status

```bash
kubectl get redb -n redis-enterprise
```

### Access Admin Console

```bash
# Get credentials
echo "Username: demo@redis.com"
kubectl get secret -n redis-enterprise rec -o jsonpath='{.data.password}' | base64 --decode
echo ""

# Port-forward
kubectl port-forward -n redis-enterprise svc/rec-ui 8443:8443
```

Open: https://localhost:8443

---

## Next Steps

- [Configure monitoring](../../monitoring/prometheus/)
- [Set up backups](../../backup-restore/)
- [Configure TLS](../../security/tls/)
- [Deploy with modules](../with-modules/)

---

## Troubleshooting

See platform-specific troubleshooting guides:
- [EKS Troubleshooting](../../platforms/eks/TROUBLESHOOTING.md)
- [GKE Troubleshooting](../../platforms/gke/TROUBLESHOOTING.md)
- [AKS Troubleshooting](../../platforms/aks/TROUBLESHOOTING.md)

