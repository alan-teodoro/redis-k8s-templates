# Multi-Namespace Deployment - Validation Steps

**Status**: ⚠️ PENDING - Requires active EKS cluster  
**Method**: Label-Based (Method 1 - Recommended)

---

## Prerequisites Verification

```bash
# 1. Verify Kubernetes cluster
kubectl version --short
kubectl get nodes

# 2. Verify Redis Enterprise Operator is installed
kubectl get deployment redis-enterprise-operator -n redis-enterprise

# 3. Verify REC is running
kubectl get rec -n redis-enterprise
# Expected: NAME=rec, NODES=3, STATE=Running

# 4. Verify operator version (must be 6.4.2-4+)
kubectl get deployment redis-enterprise-operator -n redis-enterprise -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Step 1: Create Consumer Namespaces

```bash
cd deployments/multi-namespace

# Create namespaces
kubectl apply -f 02-consumer-namespaces.yaml

# Verify namespaces created
kubectl get namespaces | grep app-
# Expected: app-production, app-staging, app-development
```

---

## Step 2: Configure RBAC for Consumer Namespaces

⚠️ **CRITICAL**: Apply RBAC **before** configuring operator to watch namespaces.

```bash
# Apply RBAC for all consumer namespaces
kubectl apply -f 03-consumer-rbac.yaml

# Verify Roles created
kubectl get role redb-role -n app-production
kubectl get role redb-role -n app-staging
kubectl get role redb-role -n app-development

# Verify RoleBindings created
kubectl get rolebinding redb-role -n app-production -o yaml
kubectl get rolebinding redb-role -n app-staging -o yaml
kubectl get rolebinding redb-role -n app-development -o yaml

# Verify RoleBindings reference correct ServiceAccounts
# Should see:
# - redis-enterprise-operator (namespace: redis-enterprise)
# - rec (namespace: redis-enterprise)
```

---

## Step 3: Configure Operator ClusterRole

```bash
# Apply ClusterRole for operator to list/watch namespaces
kubectl apply -f 01-operator-rbac.yaml

# Verify ClusterRole created
kubectl get clusterrole redis-enterprise-operator-consumer-ns

# Verify ClusterRoleBinding created
kubectl get clusterrolebinding redis-enterprise-operator-consumer-ns -o yaml
# Should bind to: redis-enterprise-operator ServiceAccount in redis-enterprise namespace
```

---

## Step 4: Configure Operator to Watch Labeled Namespaces

```bash
# Check current operator ConfigMap
kubectl get configmap operator-environment-config -n redis-enterprise -o yaml

# Patch operator ConfigMap to use label-based watching
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data": {"REDB_NAMESPACES_LABEL": "redis-multi-namespace"}}'

# Verify ConfigMap updated
kubectl get configmap operator-environment-config -n redis-enterprise -o yaml | grep REDB_NAMESPACES_LABEL

# Watch operator pod restart
kubectl get pods -n redis-enterprise -w
# Operator pod should restart after ConfigMap change
```

---

## Step 5: Label Consumer Namespaces

```bash
# Label each namespace
kubectl label namespace app-production redis-multi-namespace=enabled
kubectl label namespace app-staging redis-multi-namespace=enabled
kubectl label namespace app-development redis-multi-namespace=enabled

# Verify labels
kubectl get namespaces --show-labels | grep redis-multi-namespace

# Watch operator logs for namespace detection
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=50 -f
# Should see logs about watching new namespaces
```

---

## Step 6: Deploy REDBs to Consumer Namespaces

```bash
# Deploy production database
kubectl apply -f 04-redb-production.yaml

# Wait for REDB to become active
kubectl get redb prod-db -n app-production -w

# Deploy staging database
kubectl apply -f 05-redb-staging.yaml

# Wait for REDB to become active
kubectl get redb staging-db -n app-staging -w

# Deploy development database
kubectl apply -f 06-redb-development.yaml

# Wait for REDB to become active
kubectl get redb dev-db -n app-development -w
```

---

## Step 7: Verify Deployments

```bash
# Check all REDBs
kubectl get redb -A
# Expected:
# NAMESPACE         NAME         STATUS
# app-production    prod-db      active
# app-staging       staging-db   active
# app-development   dev-db       active

# Check production database details
kubectl describe redb prod-db -n app-production
kubectl get svc prod-db -n app-production
kubectl get secret redb-prod-db -n app-production

# Check staging database details
kubectl describe redb staging-db -n app-staging
kubectl get svc staging-db -n app-staging

# Check development database details
kubectl describe redb dev-db -n app-development
kubectl get svc dev-db -n app-development
```

---

## Step 8: Test Connectivity

```bash
# Get production database password
PROD_PASSWORD=$(kubectl get secret redb-prod-db -n app-production -o jsonpath='{.data.password}' | base64 -d)

# Port forward to production database
kubectl port-forward svc/prod-db -n app-production 12000:12000 &

# Test connection
redis-cli -h localhost -p 12000 --tls --insecure -a "$PROD_PASSWORD" PING
# Expected: PONG

# Test basic operations
redis-cli -h localhost -p 12000 --tls --insecure -a "$PROD_PASSWORD" SET test:multi-ns "production-value"
redis-cli -h localhost -p 12000 --tls --insecure -a "$PROD_PASSWORD" GET test:multi-ns
# Expected: "production-value"

# Kill port forward
pkill -f "port-forward svc/prod-db"
```

---

## Expected Results

✅ All namespaces created  
✅ All RBAC configured  
✅ Operator watching labeled namespaces  
✅ All REDBs in active state  
✅ Services created in each namespace  
✅ Secrets created in each namespace  
✅ Connectivity working  

---

## Cleanup

```bash
# Delete REDBs
kubectl delete -f 04-redb-production.yaml
kubectl delete -f 05-redb-staging.yaml
kubectl delete -f 06-redb-development.yaml

# Remove namespace labels
kubectl label namespace app-production redis-multi-namespace-
kubectl label namespace app-staging redis-multi-namespace-
kubectl label namespace app-development redis-multi-namespace-

# Delete consumer namespaces
kubectl delete -f 02-consumer-namespaces.yaml

# Delete RBAC
kubectl delete -f 03-consumer-rbac.yaml
kubectl delete -f 01-operator-rbac.yaml

# Reset operator ConfigMap
kubectl patch ConfigMap/operator-environment-config \
  -n redis-enterprise \
  --type merge \
  -p '{"data": {"REDB_NAMESPACES_LABEL": ""}}'
```

