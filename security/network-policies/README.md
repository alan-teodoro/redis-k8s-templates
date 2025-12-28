# Network Policies for Redis Enterprise

Implement network segmentation and traffic control for Redis Enterprise using Kubernetes Network Policies.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Network Policy Strategy](#network-policy-strategy)
- [Implementation](#implementation)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Kubernetes Network Policies provide network segmentation at Layer 3/4, controlling traffic between pods and external endpoints.

**Benefits:**
- ✅ Zero-trust network security
- ✅ Microsegmentation
- ✅ Defense in depth
- ✅ Compliance requirements
- ✅ Limit blast radius

---

## ✅ Prerequisites

1. **CNI Plugin with Network Policy Support**
   - Calico (recommended)
   - Cilium
   - Weave Net
   - AWS VPC CNI (with Calico)
   - Azure CNI (with Calico)
   - GKE Network Policy

2. **Verify Network Policy Support**
   ```bash
   # Check if CNI supports Network Policies
   kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'
   ```

---

## 🏗️ Network Policy Strategy

### Default Deny All (Zero-Trust)

Start with deny-all policies, then explicitly allow required traffic.

```
┌─────────────────────────────────────────────────────────────┐
│                    Default: Deny All                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Redis Enterprise Namespace                    │  │
│  │                                                        │  │
│  │  ❌ All ingress traffic blocked by default            │  │
│  │  ❌ All egress traffic blocked by default             │  │
│  │                                                        │  │
│  │  ✅ Explicitly allow required traffic only            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Allowed Traffic Patterns

```
┌─────────────────────────────────────────────────────────────┐
│              Allowed Traffic (Explicit)                      │
│                                                              │
│  1. Client Apps → Redis Database (port 12000)               │
│  2. Prometheus → Redis Metrics (port 8070)                  │
│  3. Redis → DNS (port 53)                                   │
│  4. Redis → Kubernetes API (port 443)                       │
│  5. Redis → Backup Storage (S3/GCS/Azure)                   │
│  6. Redis Nodes ↔ Redis Nodes (internode)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Implementation

### Step 1: Default Deny All

See: [01-default-deny-all.yaml](01-default-deny-all.yaml)

This policy blocks all ingress and egress traffic by default.

```bash
kubectl apply -f 01-default-deny-all.yaml
```

### Step 2: Allow DNS

See: [02-allow-dns.yaml](02-allow-dns.yaml)

Allow DNS queries (required for all pods).

```bash
kubectl apply -f 02-allow-dns.yaml
```

### Step 3: Allow Kubernetes API

See: [03-allow-k8s-api.yaml](03-allow-k8s-api.yaml)

Allow Redis Enterprise Operator to communicate with Kubernetes API.

```bash
kubectl apply -f 03-allow-k8s-api.yaml
```

### Step 4: Allow Redis Internode Traffic

See: [04-allow-redis-internode.yaml](04-allow-redis-internode.yaml)

Allow communication between Redis Enterprise nodes.

```bash
kubectl apply -f 04-allow-redis-internode.yaml
```

### Step 5: Allow Client Access to Databases

See: [05-allow-client-access.yaml](05-allow-client-access.yaml)

Allow client applications to connect to Redis databases.

```bash
kubectl apply -f 05-allow-client-access.yaml
```

### Step 6: Allow Prometheus Monitoring

See: [06-allow-prometheus.yaml](06-allow-prometheus.yaml)

Allow Prometheus to scrape Redis metrics.

```bash
kubectl apply -f 06-allow-prometheus.yaml
```

### Step 7: Allow Backup Traffic

See: [07-allow-backup.yaml](07-allow-backup.yaml)

Allow Redis to connect to backup storage (S3/GCS/Azure).

```bash
kubectl apply -f 07-allow-backup.yaml
```

---

## 🔍 Verification

### Check Network Policies

```bash
# List all network policies
kubectl get networkpolicy -n redis-enterprise

# Describe specific policy
kubectl describe networkpolicy deny-all -n redis-enterprise
```

### Test Connectivity

```bash
# Label the default namespace to allow client access
kubectl label namespace default redis-client=true

# Test Redis connection from client namespace (replace 'test-db' with your database name)
kubectl run redis-test --rm -it --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 12000 --tls --insecure -a RedisAdmin123! PING

# Expected output: PONG

# Find your database service name
kubectl get svc -n redis-enterprise | grep 12000

# Test blocked traffic (should fail)
kubectl run -it --rm debug --image=busybox --restart=Never -n redis-enterprise -- \
  wget -O- http://example.com
```

---

## 🔧 Troubleshooting

### Issue: All traffic blocked

**Solution:**
```bash
# Check if CNI supports Network Policies
kubectl get pods -n kube-system | grep -E 'calico|cilium'

# Temporarily remove deny-all to test
kubectl delete networkpolicy deny-all -n redis-enterprise
```

### Issue: DNS not working

**Solution:**
```bash
# Verify DNS policy is applied
kubectl get networkpolicy allow-dns -n redis-enterprise

# Check kube-dns/coredns namespace
kubectl get svc -n kube-system | grep dns
```

### Issue: Redis nodes cannot communicate

**Solution:**
```bash
# Verify internode policy
kubectl describe networkpolicy allow-redis-internode -n redis-enterprise

# Check pod labels match policy selectors
kubectl get pods -n redis-enterprise --show-labels
```

---

## ✅ Best Practices

### 1. **Start with Default Deny**
- ✅ Implement deny-all first
- ✅ Explicitly allow required traffic
- ✅ Test each policy incrementally

### 2. **Use Namespace Selectors**
- ✅ Allow traffic from specific namespaces only
- ✅ Use labels for fine-grained control

### 3. **Document Allowed Traffic**
- ✅ Document why each policy exists
- ✅ Include business justification
- ✅ Review policies regularly

### 4. **Monitor Network Policy Violations**
- ✅ Use CNI logging (Calico, Cilium)
- ✅ Alert on blocked traffic
- ✅ Review logs regularly

### 5. **Test Before Production**
- ✅ Test in non-production first
- ✅ Verify all required traffic flows
- ✅ Have rollback plan

### 6. **Combine with Pod Security**
- ✅ Use Network Policies + Pod Security Standards
- ✅ Defense in depth approach

---

## 📚 Related Documentation

- [Pod Security Standards](../pod-security/README.md)
- [TLS Certificates](../tls-certificates/README.md)
- [RBAC](../rbac/README.md)

---

## 🔗 References

- Kubernetes Network Policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Calico Network Policies: https://docs.tigera.io/calico/latest/network-policy/
- Cilium Network Policies: https://docs.cilium.io/en/stable/security/policy/

