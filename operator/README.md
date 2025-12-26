# Redis Enterprise Operator

## Installation

### Helm (Recommended)

```bash
# Create namespace
kubectl create namespace redis-enterprise

# Add Helm repo
helm repo add redis https://helm.redis.io
helm repo update

# Install operator (specify version for consistency)
helm install redis-operator redis/redis-enterprise-operator \
  --version 8.0.6-8 \
  -n redis-enterprise

# Verify
kubectl get pods -n redis-enterprise
kubectl get crd | grep redis
```

### RBAC for Rack Awareness (Multi-AZ)

Required for multi-AZ deployments to enable rack awareness.

```bash
kubectl apply -f ../examples/basic-deployment/rbac-rack-awareness.yaml
```

---

## Admission Controller (Optional)

Validates REDB resources before creation.

```bash
kubectl apply -f configuration/admission-controller/webhook.yaml
```

---

## Verification

```bash
# Check operator
kubectl get pods -n redis-enterprise

# Check CRDs
kubectl get crd | grep redis

# Logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50
```

---

## Troubleshooting

```bash
# Operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50

# Events
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp'
```

---

## References

- [Official Docs](https://docs.redis.com/latest/kubernetes/)
- [GitHub](https://github.com/RedisLabs/redis-enterprise-k8s-docs)

