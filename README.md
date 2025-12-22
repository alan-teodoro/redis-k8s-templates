# Redis Kubernetes Templates

This repository contains Helm values templates for deploying Redis on Kubernetes clusters using the official Redis Helm chart.

## Overview

These templates are designed for **ephemeral infrastructure** - temporary Redis deployments that will be destroyed along with their host EKS clusters after a few days.

## Official Redis Helm Chart

All templates use the official Redis Helm chart:
- **Chart Repository**: https://helm.redis.io/
- **Chart Name**: `redis/redis`
- **Documentation**: https://github.com/redis/redis-helm-charts

## Available Templates

### 1. Default (Standalone)
**File**: `redis/values-default.yaml`

Minimal configuration for quick demos:
- Single node (standalone)
- No authentication
- No persistence (ephemeral)
- Metrics enabled

**Use case**: Quick demos, testing, development

### 2. High Availability (Replication)
**File**: `redis/values-ha.yaml`

Production-like setup with replication:
- Master + 2 replicas
- Automatic failover
- No persistence (still ephemeral)
- Metrics enabled

**Use case**: HA demos, failover testing

### 3. Development (Minimal)
**File**: `redis/values-dev.yaml`

Absolute minimum resources:
- Single node
- Minimal memory/CPU
- No metrics
- No persistence

**Use case**: Resource-constrained environments, CI/CD

## Usage

### Option 1: Via Backstage Template (Recommended)

1. Navigate to Backstage
2. Select "Deploy Redis on EKS" template
3. Choose your EKS cluster
4. Select configuration (default/HA/dev)
5. Deploy!

### Option 2: Direct Helm Install

```bash
# Add Redis Helm repository
helm repo add redis https://helm.redis.io/
helm repo update

# Install with default values
helm install my-redis redis/redis \
  -f redis/values-default.yaml \
  -n default

# Install with HA configuration
helm install my-redis redis/redis \
  -f redis/values-ha.yaml \
  -n default
```

### Option 3: ArgoCD (GitOps)

```bash
# Apply ArgoCD Application
kubectl apply -f redis/argocd-app.yaml
```

## Customization

### Quick Customization (No Branch)

Edit values inline when deploying via Backstage or create a local values file:

```bash
helm install my-redis redis/redis \
  -f redis/values-default.yaml \
  --set master.resources.requests.memory=2Gi
```

### Advanced Customization (Branch)

For complex customizations:

1. Create a branch: `git checkout -b my-cluster-redis-customization`
2. Edit `redis/values-*.yaml` files
3. Commit changes
4. Use branch name in Backstage template or ArgoCD

**Note**: Since infrastructure is ephemeral, orphaned branches are not a concern - they'll be cleaned up when the cluster is destroyed.

## Connection Information

After deployment, get connection details:

```bash
# Get Redis password (if auth enabled)
export REDIS_PASSWORD=$(kubectl get secret my-redis -o jsonpath="{.data.redis-password}" | base64 -d)

# Port forward to access locally
kubectl port-forward svc/my-redis-master 6379:6379

# Connect with redis-cli
redis-cli -h 127.0.0.1 -p 6379 -a $REDIS_PASSWORD
```

## Cleanup

### Manual Cleanup
```bash
helm uninstall my-redis -n default
```

### Automatic Cleanup
When the EKS cluster is destroyed (via Backstage TTL), all Redis deployments are automatically removed.

## Architecture

```
┌─────────────────────────────────────────┐
│         EKS Cluster (Ephemeral)         │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     Redis Deployment              │  │
│  │                                   │  │
│  │  ┌──────────┐    ┌──────────┐    │  │
│  │  │  Master  │───▶│ Replica  │    │  │
│  │  └──────────┘    └──────────┘    │  │
│  │                                   │  │
│  │  Service: my-redis-master         │  │
│  │  Service: my-redis-replicas       │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Deployed via: Backstage + ArgoCD/Helm  │
└─────────────────────────────────────────┘
```

## Support

For issues or questions:
- Check official Redis Helm chart docs: https://github.com/redis/redis-helm-charts
- Contact Redis Professional Services team

## License

MIT License - See official Redis Helm chart for chart-specific licensing.
