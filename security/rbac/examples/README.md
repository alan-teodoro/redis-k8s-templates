# Custom RBAC Examples

## ⚠️ **Important Notice**

These are **OPTIONAL EXAMPLES** for specific use cases.

**The Redis Enterprise Operator already includes all necessary RBAC when installed via Helm or bundle.**

**You do NOT need these unless you have specific requirements** (see [../README.md](../README.md) for when to use).

---

## 📦 **Available Examples**

### 1. Read-Only RBAC

**File:** [readonly-rbac.yaml](readonly-rbac.yaml)

**Use Case:** Monitoring tools (Prometheus, Grafana) that need to read Redis resources but not modify them.

**Permissions:**
- ✅ Read REC/REDB resources
- ✅ Read pods, services, configmaps
- ✅ Read events
- ❌ Cannot create/update/delete anything
- ❌ Cannot access secrets

**Example Usage:**
```bash
# Apply the role
kubectl apply -f readonly-rbac.yaml

# Bind to Prometheus ServiceAccount (in monitoring namespace)
kubectl create rolebinding prometheus-redis-readonly \
  -n redis-enterprise \
  --role=redis-readonly \
  --serviceaccount=monitoring:prometheus
```

---

### 2. Developer RBAC

**File:** [developer-rbac.yaml](developer-rbac.yaml)

**Use Case:** Application teams or CI/CD pipelines that need to create databases but not modify cluster configuration.

**Permissions:**
- ✅ Full access to REDB (create/update/delete databases)
- ✅ Read-only access to REC (view cluster status)
- ✅ Read pods, services, configmaps
- ❌ Cannot modify REC (cluster configuration)
- ❌ Cannot access secrets

**Example Usage:**
```bash
# Apply the role
kubectl apply -f developer-rbac.yaml

# Bind to a user
kubectl create rolebinding developer-john \
  -n redis-enterprise \
  --role=redis-developer \
  --user=john@example.com

# Or bind to a CI/CD ServiceAccount
kubectl create rolebinding ci-database-provisioner \
  -n redis-enterprise \
  --role=redis-developer \
  --serviceaccount=ci-cd:database-provisioner
```

---

### 3. Admin RBAC

**File:** [admin-rbac.yaml](admin-rbac.yaml)

**Use Case:** Platform team that manages the Redis Enterprise Cluster.

**Permissions:**
- ✅ Full access to REC (cluster configuration)
- ✅ Full access to REDB (databases)
- ✅ Full access to pods, services, secrets, configmaps
- ✅ Can manage all Redis Enterprise resources

**Example Usage:**
```bash
# Apply the role
kubectl apply -f admin-rbac.yaml

# Bind to platform team group
kubectl create rolebinding platform-team-admins \
  -n redis-enterprise \
  --role=redis-admin \
  --group=platform-team
```

---

## 🎯 **Common Scenarios**

### Scenario 1: Multi-Tenant Cluster

**Problem:** Multiple teams share the same Kubernetes cluster.

**Solution:**
```bash
# Platform team manages cluster
kubectl apply -f admin-rbac.yaml
kubectl create rolebinding platform-admins \
  -n redis-enterprise \
  --role=redis-admin \
  --group=platform-team

# App teams create databases
kubectl apply -f developer-rbac.yaml
kubectl create rolebinding app-team-a \
  -n redis-enterprise \
  --role=redis-developer \
  --group=app-team-a

# Monitoring team reads metrics
kubectl apply -f readonly-rbac.yaml
kubectl create rolebinding monitoring \
  -n redis-enterprise \
  --role=redis-readonly \
  --serviceaccount=monitoring:prometheus
```

---

### Scenario 2: GitOps Database Provisioning

**Problem:** Developers create databases via ArgoCD/Flux, but you don't want them to modify cluster configuration.

**Solution:**
```bash
# Create ServiceAccount for ArgoCD
kubectl create serviceaccount argocd-redis -n redis-enterprise

# Apply developer role
kubectl apply -f developer-rbac.yaml

# Bind ArgoCD ServiceAccount to developer role
kubectl create rolebinding argocd-redis-developer \
  -n redis-enterprise \
  --role=redis-developer \
  --serviceaccount=redis-enterprise:argocd-redis

# Now ArgoCD can create REDB but not modify REC
```

---

### Scenario 3: Compliance (SOC2/HIPAA)

**Problem:** Need to prove separation of duties for audits.

**Solution:**
```bash
# Apply all roles
kubectl apply -f readonly-rbac.yaml
kubectl apply -f developer-rbac.yaml
kubectl apply -f admin-rbac.yaml

# Bind to different groups
kubectl create rolebinding sre-readonly \
  -n redis-enterprise \
  --role=redis-readonly \
  --group=sre-team

kubectl create rolebinding developers \
  -n redis-enterprise \
  --role=redis-developer \
  --group=developers

kubectl create rolebinding platform-admins \
  -n redis-enterprise \
  --role=redis-admin \
  --group=platform-admins

# Document in compliance audit:
# - SRE team: Read-only access (monitoring)
# - Developers: Can create databases, cannot modify cluster
# - Platform admins: Full access to cluster configuration
```

---

## 🔍 **Testing Permissions**

### Test Read-Only Role

```bash
# Should succeed (read access)
kubectl auth can-i get redb \
  --as=system:serviceaccount:redis-enterprise:redis-readonly \
  -n redis-enterprise

# Should fail (no write access)
kubectl auth can-i delete redb \
  --as=system:serviceaccount:redis-enterprise:redis-readonly \
  -n redis-enterprise

# Should fail (no secret access)
kubectl auth can-i get secrets \
  --as=system:serviceaccount:redis-enterprise:redis-readonly \
  -n redis-enterprise
```

### Test Developer Role

```bash
# Should succeed (can manage databases)
kubectl auth can-i create redb \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise

kubectl auth can-i delete redb \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise

# Should succeed (can read cluster)
kubectl auth can-i get rec \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise

# Should fail (cannot modify cluster)
kubectl auth can-i delete rec \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise

# Should fail (no secret access)
kubectl auth can-i get secrets \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise
```

### Test Admin Role

```bash
# Should succeed (full access)
kubectl auth can-i '*' '*' \
  --as=system:serviceaccount:redis-enterprise:redis-admin \
  -n redis-enterprise
```

---

## 📚 **Related Documentation**

- [Main RBAC README](../README.md) - When to use custom RBAC
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Redis Enterprise Operator](https://redis.io/docs/latest/operate/kubernetes/)

