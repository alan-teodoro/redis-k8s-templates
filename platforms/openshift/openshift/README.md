# OpenShift-Specific Configurations

This directory contains OpenShift-specific configurations required for Redis Enterprise deployment.

## 📋 Overview

OpenShift has additional security requirements compared to standard Kubernetes. The Security Context Constraints (SCC) defined here grant the necessary permissions for Redis Enterprise to operate properly.

## 🔐 Security Context Constraints (SCC)

### What is an SCC?

Security Context Constraints control what actions pods can perform and what resources they can access. Redis Enterprise requires specific capabilities to manage system resources effectively.

### Why is this SCC needed?

Redis Enterprise needs the `SYS_RESOURCE` capability to:
- **Manage file descriptor limits** for database shards
- **Adjust OOM (Out of Memory) scores** to prevent critical processes from being killed
- **Optimize system resources** for high-performance database operations

### SCC Details

**File:** `scc.yaml`

**Key Features:**
- **Name:** `redis-enterprise-scc-v2`
- **UID/GID:** Enforces UID 1001 (Redis Enterprise container user)
- **Capabilities:** Allows `SYS_RESOURCE` only
- **SELinux:** Enforces SELinux context
- **Seccomp:** Uses runtime/default profile for syscall filtering
- **Based on:** OpenShift's `restricted-v2` SCC with minimal additions

## 🚀 Deployment

### When to Apply

Apply the SCC **BEFORE** deploying Redis Enterprise Cluster, but **AFTER** installing the operator.

### Installation Steps

#### 1. Apply the SCC

```bash
oc apply -f openshift/scc.yaml
```

#### 2. Bind SCC to Service Accounts

**For Single-Region Deployment:**
```bash
# Replace 'redis-ns-a' with your namespace
oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-a:redis-enterprise-operator

oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-a:rec
```

**For Active-Active Deployment:**
```bash
# Cluster A
oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-a:redis-enterprise-operator

oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-a:rec-a

# Cluster B
oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-b:redis-enterprise-operator

oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:redis-ns-b:rec-b
```

#### 3. Verify SCC Binding

```bash
# Check SCC exists
oc get scc redis-enterprise-scc-v2

# Verify service account bindings
oc describe scc redis-enterprise-scc-v2
```

## ⚠️ Important Notes

### Operator Installation Method

**If installed via OperatorHub:**
- The operator may automatically create and manage SCCs
- You might not need to apply this SCC manually
- Check if `redis-enterprise-scc` or similar already exists

**If installed manually:**
- You **MUST** apply this SCC
- Bind it to the appropriate service accounts
- Verify permissions before deploying clusters

### Namespace-Specific

The SCC itself is cluster-wide, but you must bind it to service accounts in **each namespace** where you deploy Redis Enterprise.

### Service Account Names

The service account names depend on your cluster name:
- Operator service account: `redis-enterprise-operator` (fixed)
- Cluster service account: `rec`, `rec-a`, `rec-b`, etc. (matches cluster name)

## 🔍 Troubleshooting

### Permission Denied Errors

If you see errors like:
```
Error: container has runAsNonRoot and image will run as root
```

**Solution:**
1. Verify SCC is applied: `oc get scc redis-enterprise-scc-v2`
2. Check SCC binding: `oc describe scc redis-enterprise-scc-v2`
3. Verify service accounts exist: `oc get sa -n <namespace>`
4. Re-apply SCC binding commands

### SCC Not Taking Effect

```bash
# Delete and recreate the pods
oc delete pod -l app=redis-enterprise -n <namespace>

# Pods will be recreated with correct SCC
```

### Check Which SCC is Being Used

```bash
# Get pod details
oc get pod <pod-name> -n <namespace> -o yaml | grep scc

# Should show: openshift.io/scc: redis-enterprise-scc-v2
```

## 🔐 Security Considerations

### Why These Permissions Are Safe

1. **Minimal Capabilities**: Only `SYS_RESOURCE` is granted, not full privileged access
2. **Specific UID**: Enforces UID 1001, preventing root execution
3. **SELinux Enforced**: Maintains SELinux security context
4. **Seccomp Profile**: Filters system calls for additional security
5. **No Host Access**: Prevents access to host network, PID, IPC

### Comparison to Standard SCCs

| Feature | restricted-v2 | redis-enterprise-scc-v2 |
|---------|---------------|-------------------------|
| SYS_RESOURCE | ❌ No | ✅ Yes |
| Run as Root | ❌ No | ❌ No |
| Host Network | ❌ No | ❌ No |
| Privileged | ❌ No | ❌ No |
| SELinux | ✅ Yes | ✅ Yes |
| Seccomp | ✅ Yes | ✅ Yes |

## 📚 Additional Resources

- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Redis Enterprise on OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)
- [Redis Enterprise Security](https://redis.io/docs/latest/operate/rs/security/)
- [Understanding SYS_RESOURCE Capability](https://man7.org/linux/man-pages/man7/capabilities.7.html)

## 🧹 Cleanup

To remove the SCC (only do this when completely removing Redis Enterprise):

```bash
# Remove SCC bindings first
oc adm policy remove-scc-from-user redis-enterprise-scc-v2 \
  system:serviceaccount:<namespace>:redis-enterprise-operator

oc adm policy remove-scc-from-user redis-enterprise-scc-v2 \
  system:serviceaccount:<namespace>:rec

# Delete the SCC
oc delete scc redis-enterprise-scc-v2
```

