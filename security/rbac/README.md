# Kubernetes RBAC for Redis Enterprise

## ⚠️ **Do You Need Custom RBAC?**

**The Redis Enterprise Operator Helm chart and bundle ALREADY INCLUDE all necessary RBAC.**

When you install the operator, it automatically creates:
- ✅ ServiceAccount for the operator
- ✅ Role/ClusterRole with required permissions
- ✅ RoleBinding/ClusterRoleBinding

**You do NOT need to apply any RBAC manually unless you have specific requirements.**

---

## ❌ **You DON'T Need Custom RBAC If:**

- Dedicated Kubernetes cluster for Redis Enterprise
- Small team (< 10 people) with admin access
- Dev/test environment
- Everyone has cluster-admin permissions

**→ Skip this section entirely. The operator's built-in RBAC is sufficient.**

---

## ✅ **You NEED Custom RBAC Only If:**

### **1. Multi-Tenant Cluster (Shared with Other Teams)**

**Scenario:** Kubernetes cluster shared by multiple teams/applications.

**Example:**
```
├── namespace: redis-enterprise (Platform Team)
├── namespace: app-team-a (Application Team A)
├── namespace: app-team-b (Application Team B)
└── namespace: monitoring (SRE Team)
```

**Solution:** Use custom RBAC to:
- Allow monitoring team (Prometheus) read-only access → [examples/readonly-rbac.yaml](examples/readonly-rbac.yaml)
- Allow app teams to create databases but not modify cluster → [examples/developer-rbac.yaml](examples/developer-rbac.yaml)
- Restrict platform team to manage cluster only → [examples/admin-rbac.yaml](examples/admin-rbac.yaml)

---

### **2. Compliance Requirements (SOC2, HIPAA, PCI-DSS)**

**Scenario:** You need to prove separation of duties and least privilege for audits.

**Solution:** Implement granular RBAC with:
- Separate roles for different responsibilities
- Audit trail of who can do what
- Documentation for compliance auditors

See: [examples/](examples/) for reference implementations.

---

### **3. Self-Service Database Provisioning**

**Scenario:** Developers create databases via GitOps (ArgoCD/Flux) or CI/CD pipelines.

**Example:**
```yaml
# CI/CD pipeline ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: database-provisioner
  namespace: redis-enterprise
---
# Bind to developer role (can create REDB, cannot modify REC)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: database-provisioner
  namespace: redis-enterprise
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: redis-developer
subjects:
  - kind: ServiceAccount
    name: database-provisioner
    namespace: redis-enterprise
```

**Solution:** Use [examples/developer-rbac.yaml](examples/developer-rbac.yaml) to:
- Allow creating/updating/deleting REDB (databases)
- Prevent modifying REC (cluster configuration)
- Prevent accessing secrets

---

### **4. Large Organization (100+ Developers)**

**Scenario:** Multiple teams need different levels of access.

**Teams:**
- **Platform Team:** Manages Redis Enterprise Cluster (REC)
- **Application Teams:** Create databases (REDB)
- **SRE Team:** Read-only monitoring access
- **Security Team:** Audit access

**Solution:** Implement role-based access:
- Platform Team → [examples/admin-rbac.yaml](examples/admin-rbac.yaml)
- Application Teams → [examples/developer-rbac.yaml](examples/developer-rbac.yaml)
- SRE Team → [examples/readonly-rbac.yaml](examples/readonly-rbac.yaml)

---

## 📦 **What's Included in Operator RBAC (Automatic)**

When you install the operator via Helm or bundle, it creates:

```yaml
# ServiceAccount (automatically created)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: redis-enterprise-operator
  namespace: redis-enterprise

---
# Role (automatically created)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: redis-enterprise-operator
  namespace: redis-enterprise
rules:
  - apiGroups: ["app.redislabs.com"]
    resources: ["redisenterpriseclusters", "redisenterprisedatabases"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["pods", "services", "secrets", "configmaps", "persistentvolumeclaims"]
    verbs: ["*"]
  # ... (full permissions for operator to function)

---
# RoleBinding (automatically created)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: redis-enterprise-operator
  namespace: redis-enterprise
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: redis-enterprise-operator
subjects:
  - kind: ServiceAccount
    name: redis-enterprise-operator
    namespace: redis-enterprise
```

**You don't need to create this manually!**

---

## 📚 **Custom RBAC Examples**

If you determined you need custom RBAC, see the [examples/](examples/) directory:

- **[readonly-rbac.yaml](examples/readonly-rbac.yaml)** - For monitoring tools (Prometheus, Grafana)
- **[developer-rbac.yaml](examples/developer-rbac.yaml)** - For application teams (create databases only)
- **[admin-rbac.yaml](examples/admin-rbac.yaml)** - For platform teams (full access)

**⚠️ These are EXAMPLES. Adapt them to your specific requirements.**

---

## 🔍 **Verification**

### Check Operator RBAC (Automatically Created)

```bash
# Check ServiceAccount
kubectl get serviceaccount -n redis-enterprise | grep operator

# Check Role
kubectl get role -n redis-enterprise | grep operator

# Check RoleBinding
kubectl get rolebinding -n redis-enterprise | grep operator

# Verify operator has permissions
kubectl auth can-i create redb \
  --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator \
  -n redis-enterprise
# Should return: yes
```

### Test Custom RBAC (If You Created It)

```bash
# Test developer role (can create databases)
kubectl auth can-i create redb \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise
# Should return: yes

# Test developer role (cannot modify cluster)
kubectl auth can-i delete rec \
  --as=system:serviceaccount:redis-enterprise:redis-developer \
  -n redis-enterprise
# Should return: no

# Test readonly role (can view, cannot modify)
kubectl auth can-i get pods \
  --as=system:serviceaccount:redis-enterprise:redis-readonly \
  -n redis-enterprise
# Should return: yes

kubectl auth can-i delete pods \
  --as=system:serviceaccount:redis-enterprise:redis-readonly \
  -n redis-enterprise
# Should return: no
```

---

## 📚 **Related Documentation**

- [Pod Security Standards](../pod-security/README.md)
- [Network Policies](../network-policies/README.md)
- [External Secrets](../external-secrets/README.md)

---

## 🔗 **References**

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Redis Enterprise Operator Installation](https://redis.io/docs/latest/operate/kubernetes/deployment/quick-start/)

