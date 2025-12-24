# Redis Enterprise Operator

The Redis Enterprise Operator manages Redis Enterprise clusters on Kubernetes.

## Overview

The operator automates:
- Redis Enterprise Cluster (REC) deployment and lifecycle
- Database (REDB) creation and management
- Active-Active database (REAADB) configuration
- Upgrades and scaling operations

## Directory Structure

```
operator/
├── installation/
│   ├── helm/           # Helm-based installation (recommended)
│   ├── olm/            # Operator Lifecycle Manager (OpenShift)
│   └── manual/         # Manual YAML installation
├── upgrades/           # Upgrade procedures and guides
└── configuration/      # Operator configuration options
```

## Installation Methods

### 1. Helm (Recommended for most platforms)
**Location:** `installation/helm/`

Best for: EKS, AKS, GKE, vanilla Kubernetes

```bash
helm repo add redis https://helm.redis.io/
helm install redis-operator redis/redis-enterprise-operator \
  -n redis-system --create-namespace
```

### 2. Operator Lifecycle Manager (OLM)
**Location:** `installation/olm/`

Best for: OpenShift

Install via OperatorHub in OpenShift Console or:
```bash
oc apply -f installation/olm/subscription.yaml
```

### 3. Manual YAML
**Location:** `installation/manual/`

Best for: Air-gapped environments, custom configurations

```bash
kubectl apply -f installation/manual/
```

## Quick Start

1. **Choose installation method** based on your platform
2. **Navigate to the appropriate directory**
3. **Follow the README** in that directory
4. **Verify installation:**
   ```bash
   kubectl get pods -n redis-system
   kubectl get crd | grep redis
   ```

## Custom Resource Definitions (CRDs)

The operator installs these CRDs:

| CRD | Description |
|-----|-------------|
| `RedisEnterpriseCluster` (REC) | Redis Enterprise cluster |
| `RedisEnterpriseDatabase` (REDB) | Redis database |
| `RedisEnterpriseActiveActiveDatabase` (REAADB) | Active-Active database |
| `RedisEnterpriseRemoteCluster` (RERC) | Remote cluster for AA |

## Operator Configuration

### Admission Controller (Recommended)

The admission controller validates REDB resources before they are applied. **Strongly recommended** for production.

See [`configuration/admission-controller/`](configuration/admission-controller/) for:
- Setup instructions
- ValidatingWebhookConfiguration
- Test files

**Quick setup:**
```bash
# 1. Apply webhook
kubectl apply -f configuration/admission-controller/webhook.yaml

# 2. Patch with certificate
CERT=$(kubectl get secret admission-tls -n redis-enterprise -o jsonpath='{.data.cert}')
kubectl patch ValidatingWebhookConfiguration redis-enterprise-admission \
  --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/clientConfig/caBundle', 'value':'${CERT}'}]"

# 3. Test
kubectl apply -f configuration/admission-controller/test-invalid-redb.yaml
```

### Other Configuration Options

Additional configuration in `configuration/`:
- Resource limits and requests
- Image pull secrets
- RBAC customization

## Upgrades

See `upgrades/` directory for:
- Operator upgrade procedures
- Redis Enterprise version upgrades
- Compatibility matrix
- Rollback procedures

## Platform-Specific Notes

### OpenShift
- Install via OperatorHub (OLM) recommended
- Security Context Constraints (SCC) automatically configured
- See `platforms/openshift/` for complete examples

### EKS
- Use Helm installation
- Ensure EBS CSI driver is installed
- See `platforms/eks/` for complete examples

### AKS
- Use Helm installation
- Ensure Azure Disk CSI driver is installed
- See `platforms/aks/` for complete examples

### GKE
- Use Helm installation
- Ensure Persistent Disk CSI driver is installed
- See `platforms/gke/` for complete examples

## Verification

After installation, verify the operator is running:

```bash
# Check operator pod
kubectl get pods -n redis-system

# Check CRDs are installed
kubectl get crd | grep redis

# Check operator logs
kubectl logs -n redis-system -l name=redis-enterprise-operator

# Verify webhook is configured
kubectl get validatingwebhookconfigurations | grep redis
```

## Next Steps

After installing the operator:
1. Deploy a Redis Enterprise Cluster - see `deployments/redis-enterprise/single-cluster/`
2. Create databases - examples in deployment directories
3. Configure monitoring - see `monitoring/`
4. Set up security - see `security/`

## Troubleshooting

See `docs/troubleshooting.md` for common operator issues.

Quick checks:
```bash
# Operator logs
kubectl logs -n redis-system -l name=redis-enterprise-operator --tail=50

# Events
kubectl get events -n redis-system --sort-by='.lastTimestamp'

# Operator status
kubectl get deployment -n redis-system
```

## Resources

- [Official Operator Documentation](https://docs.redis.com/latest/kubernetes/)
- [Operator GitHub Repository](https://github.com/RedisLabs/redis-enterprise-k8s-docs)
- [Operator Helm Chart](https://github.com/RedisLabs/redis-enterprise-k8s-docs/tree/master/helm)

