# Pod Security Standards for Redis Enterprise

Implement Pod Security Standards to enforce security best practices for Redis Enterprise pods.

## 📋 Table of Contents

- [Overview](#overview)
- [Pod Security Standards](#pod-security-standards)
- [Implementation](#implementation)
- [Security Context](#security-context)
- [Verification](#verification)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Pod Security Standards define three levels of security policies for pods:
- **Privileged**: Unrestricted (not recommended)
- **Baseline**: Minimally restrictive (default)
- **Restricted**: Heavily restricted (most secure)

**Benefits:**
- ✅ Prevent privilege escalation
- ✅ Enforce security best practices
- ✅ Compliance requirements
- ✅ Defense in depth

---

## 🔒 Pod Security Standards

### Privileged (Not Recommended)

Unrestricted policy - allows all capabilities.

**Use Case:** Only for system-level components

### Baseline (Recommended for Redis Enterprise)

Prevents known privilege escalations while minimizing restrictions.

**Restrictions:**
- ❌ No host namespaces (hostNetwork, hostPID, hostIPC)
- ❌ No privileged containers
- ❌ No host path volumes
- ❌ Limited capabilities
- ✅ Allows non-root users
- ✅ Allows volume types (emptyDir, configMap, secret, PVC)

### Restricted (Most Secure)

Heavily restricted - follows current pod hardening best practices.

**Additional Restrictions:**
- ❌ Must run as non-root
- ❌ Must drop ALL capabilities
- ❌ No privilege escalation
- ❌ Read-only root filesystem (where possible)
- ❌ Seccomp profile required

---

## 📦 Implementation

### Method 1: Pod Security Admission (Kubernetes 1.25+)

See: [01-pod-security-admission.yaml](01-pod-security-admission.yaml)

```bash
# Apply Pod Security Standards to namespace
kubectl apply -f 01-pod-security-admission.yaml
```

### Method 2: Security Context (All Versions)

See: [02-security-context.yaml](02-security-context.yaml)

```bash
# Apply REC with security context
kubectl apply -f 02-security-context.yaml
```

---

## 🔐 Security Context

### Pod-Level Security Context

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
```

### Container-Level Security Context

```yaml
spec:
  containers:
    - name: redis-enterprise
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: false  # Redis needs write access
        runAsNonRoot: true
        runAsUser: 1001
        capabilities:
          drop:
            - ALL
          add:
            - NET_BIND_SERVICE  # Only if binding to ports < 1024
```

---

## 🔍 Verification

### Check Pod Security Standards

```bash
# Check namespace labels
kubectl get namespace redis-enterprise --show-labels

# Check pod security context
kubectl get pod rec-0 -n redis-enterprise -o jsonpath='{.spec.securityContext}'

# Check container security context
kubectl get pod rec-0 -n redis-enterprise \
  -o jsonpath='{.spec.containers[0].securityContext}'
```

### Test Pod Security

```bash
# Try to create privileged pod (should fail with Restricted)
kubectl run -it --rm test --image=nginx --restart=Never -n redis-enterprise \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","securityContext":{"privileged":true}}]}}'

# Should fail with: "pods 'test' is forbidden: violates PodSecurity"
```

---

## ✅ Best Practices

### 1. **Use Baseline for Redis Enterprise**
- ✅ Redis Enterprise requires some privileges
- ✅ Baseline provides good security without breaking functionality
- ✅ Restricted may be too restrictive

### 2. **Enforce at Namespace Level**
- ✅ Use Pod Security Admission labels
- ✅ Apply to entire namespace
- ✅ Consistent enforcement

### 3. **Use Security Context**
- ✅ Always define securityContext
- ✅ Run as non-root when possible
- ✅ Drop unnecessary capabilities

### 4. **Monitor Violations**
- ✅ Set up alerts for policy violations
- ✅ Review audit logs
- ✅ Investigate failures

### 5. **Test Before Production**
- ✅ Test in non-production first
- ✅ Verify all functionality works
- ✅ Have rollback plan

---

## 📚 Related Documentation

- [Network Policies](../network-policies/README.md)
- [RBAC](../rbac/README.md)
- [TLS Certificates](../tls-certificates/README.md)

---

## 🔗 References

- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Pod Security Admission: https://kubernetes.io/docs/concepts/security/pod-security-admission/
- Security Context: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

