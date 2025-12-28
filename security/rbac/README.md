# Kubernetes RBAC for Redis Enterprise

Implement Role-Based Access Control (RBAC) for Redis Enterprise on Kubernetes.

## 📋 Table of Contents

- [Overview](#overview)
- [RBAC Components](#rbac-components)
- [Implementation](#implementation)
- [Use Cases](#use-cases)
- [Verification](#verification)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Kubernetes RBAC controls access to Kubernetes API resources.

**Benefits:**
- ✅ Principle of least privilege
- ✅ Separation of duties
- ✅ Audit trail
- ✅ Compliance requirements

---

## 🔐 RBAC Components

### 1. ServiceAccount
Identity for pods and processes.

### 2. Role / ClusterRole
Defines permissions (what can be done).

### 3. RoleBinding / ClusterRoleBinding
Binds roles to subjects (who can do it).

---

## 🏗️ RBAC Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RBAC Architecture                         │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐ │
│  │ ServiceAccount│ ───▶ │ RoleBinding  │ ───▶ │   Role    │ │
│  │   (Who)       │      │   (Binds)    │      │  (What)   │ │
│  └──────────────┘      └──────────────┘      └───────────┘ │
│                                                              │
│  Example:                                                    │
│  redis-operator ────▶ operator-binding ────▶ operator-role  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Implementation

### Redis Enterprise Operator RBAC

The operator needs permissions to manage REC/REDB resources.

See: [01-operator-rbac.yaml](01-operator-rbac.yaml)

```bash
kubectl apply -f 01-operator-rbac.yaml
```

### Read-Only Access

For monitoring and observability tools.

See: [02-readonly-rbac.yaml](02-readonly-rbac.yaml)

```bash
kubectl apply -f 02-readonly-rbac.yaml
```

### Developer Access

For developers who need to manage databases.

See: [03-developer-rbac.yaml](03-developer-rbac.yaml)

```bash
kubectl apply -f 03-developer-rbac.yaml
```

### Admin Access

For administrators who need full access.

See: [04-admin-rbac.yaml](04-admin-rbac.yaml)

```bash
kubectl apply -f 04-admin-rbac.yaml
```

---

## 🎯 Use Cases

### 1. Redis Enterprise Operator

**Needs:**
- Create/update/delete REC/REDB
- Manage pods, services, secrets
- Access Kubernetes API

**Solution:** [01-operator-rbac.yaml](01-operator-rbac.yaml)

### 2. Monitoring (Prometheus)

**Needs:**
- Read pods, services
- Scrape metrics endpoints

**Solution:** [02-readonly-rbac.yaml](02-readonly-rbac.yaml)

### 3. Developers

**Needs:**
- Create/update/delete REDB
- View REC status
- No access to secrets

**Solution:** [03-developer-rbac.yaml](03-developer-rbac.yaml)

### 4. Administrators

**Needs:**
- Full access to all resources
- Manage REC and REDB
- Access secrets

**Solution:** [04-admin-rbac.yaml](04-admin-rbac.yaml)

---

## 🔍 Verification

### Check ServiceAccounts

```bash
# List service accounts
kubectl get serviceaccount -n redis-enterprise

# Describe service account
kubectl describe serviceaccount redis-operator -n redis-enterprise
```

### Check Roles

```bash
# List roles
kubectl get role -n redis-enterprise

# List cluster roles
kubectl get clusterrole | grep redis

# Describe role
kubectl describe role redis-operator -n redis-enterprise
```

### Check RoleBindings

```bash
# List role bindings
kubectl get rolebinding -n redis-enterprise

# List cluster role bindings
kubectl get clusterrolebinding | grep redis

# Describe role binding
kubectl describe rolebinding redis-operator -n redis-enterprise
```

### Test Permissions

```bash
# Test as specific service account
kubectl auth can-i create redb --as=system:serviceaccount:redis-enterprise:redis-developer

# Test all permissions
kubectl auth can-i --list --as=system:serviceaccount:redis-enterprise:redis-developer
```

---

## ✅ Best Practices

### 1. **Principle of Least Privilege**
- ✅ Grant minimum required permissions
- ✅ Use Role instead of ClusterRole when possible
- ✅ Avoid wildcard permissions (*)

### 2. **Separation of Duties**
- ✅ Different roles for different teams
- ✅ Operators vs Developers vs Admins
- ✅ Read-only for monitoring

### 3. **Use ServiceAccounts**
- ✅ One ServiceAccount per component
- ✅ Don't use default ServiceAccount
- ✅ Bind to specific roles

### 4. **Regular Audits**
- ✅ Review permissions regularly
- ✅ Remove unused ServiceAccounts
- ✅ Check for overly permissive roles

### 5. **Namespace Isolation**
- ✅ Use Role/RoleBinding for namespace-scoped access
- ✅ Use ClusterRole/ClusterRoleBinding only when needed
- ✅ Separate namespaces for different environments

---

## 📚 Related Documentation

- [Pod Security Standards](../pod-security/README.md)
- [Network Policies](../network-policies/README.md)
- [External Secrets](../external-secrets/README.md)

---

## 🔗 References

- Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Using RBAC Authorization: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

