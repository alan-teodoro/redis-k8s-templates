# REDB Admission Controller

The **REDB Admission Controller** is a Kubernetes ValidatingWebhookConfiguration that validates RedisEnterpriseDatabase (REDB) manifests before they are applied to the cluster.

## 🎯 Purpose

The admission controller prevents invalid REDB configurations from being created, catching errors **before** they cause issues in production.

**It is HIGHLY RECOMMENDED to deploy the REDB admission controller in all environments.**

---

## ✅ What It Validates

The REDB admission controller validates:

1. **Resource Limits**: Ensures memory/CPU requests are within cluster capacity
2. **Database Names**: Validates database name format and uniqueness
3. **Replication**: Ensures replication settings are valid
4. **Persistence**: Validates persistence configuration
5. **Modules**: Checks module compatibility and versions
6. **Backup Configuration**: Validates backup settings (S3/GCS/Azure)
7. **TLS Configuration**: Ensures TLS settings are correct
8. **Eviction Policy**: Validates eviction policy values
9. **Shard Count**: Ensures shard count is appropriate for memory size

---

## 🚀 Installation

### Automatic Installation (OpenShift OLM)

If you installed the Redis Enterprise Operator via **OpenShift OLM (Operator Lifecycle Manager)**, the REDB admission controller is **automatically deployed**.

No additional steps required! ✅

### Manual Installation (Helm or kubectl)

If you installed the operator manually, you need to enable the admission controller:

#### Option 1: Helm Installation

```bash
# Install operator with admission controller enabled
helm install redis-enterprise-operator \
  redislabs/redis-enterprise-operator \
  --namespace redis-enterprise \
  --create-namespace \
  --set admissionController.enabled=true
```

#### Option 2: kubectl Installation

```bash
# Download operator bundle
VERSION=8.0.6-8
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/v${VERSION}/bundle.yaml

# The admission controller is included in the bundle
# Verify it's running:
kubectl get validatingwebhookconfiguration | grep redis
```

---

## 🔍 Verification

### Check if Admission Controller is Running

```bash
# Check ValidatingWebhookConfiguration
kubectl get validatingwebhookconfiguration | grep redis

# Expected output:
# NAME                                      WEBHOOKS   AGE
# redb-admission                            1          10m
```

### Check Webhook Details

```bash
# Describe the webhook
kubectl describe validatingwebhookconfiguration redb-admission

# Expected output should show:
# - Webhook name: redb-admission
# - Service: redis-enterprise-operator
# - Path: /admission
# - Rules: CREATE, UPDATE on redisenterprisedb resources
```

### Check Admission Controller Logs

```bash
# Get operator pod name
OPERATOR_POD=$(kubectl get pod -n redis-enterprise -l name=redis-enterprise-operator -o jsonpath='{.items[0].metadata.name}')

# Check logs for admission controller
kubectl logs -n redis-enterprise $OPERATOR_POD | grep admission
```

---

## 🧪 Testing the Admission Controller

### Test 1: Invalid Memory Size

Create an invalid REDB with memory size exceeding cluster capacity:

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: invalid-db
  namespace: redis-enterprise
spec:
  memorySize: 1000GB  # Exceeds cluster capacity
```

```bash
kubectl apply -f invalid-db.yaml
```

**Expected Result:** ❌ Rejected with error message:
```
Error from server: admission webhook "redb-admission" denied the request:
memory size 1000GB exceeds cluster capacity
```

### Test 2: Invalid Database Name

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: Invalid_DB_Name!  # Invalid characters
  namespace: redis-enterprise
spec:
  memorySize: 1GB
```

**Expected Result:** ❌ Rejected with error message about invalid name format

### Test 3: Valid REDB

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: valid-db
  namespace: redis-enterprise
spec:
  memorySize: 1GB
  replication: true
```

**Expected Result:** ✅ Accepted and created successfully

---

## ⚠️ IMPORTANT NOTES

### 1. Admission Controller is HIGHLY RECOMMENDED

**✅ DO:**
- Deploy the REDB admission controller in ALL environments (dev, staging, prod)
- It prevents invalid configurations from being applied
- Catches errors early, before they cause production issues

**❌ DON'T:**
- Skip the admission controller deployment
- Disable it in production environments

### 2. Automatic Deployment with OLM

If you use **OpenShift OLM**, the admission controller is automatically deployed. No manual steps needed.

### 3. Webhook Failures

If the admission controller webhook is unavailable, REDB creation will **fail** by default (fail-closed).

This is a safety feature to prevent invalid configurations.

---

## 🔧 Troubleshooting

### Issue: REDB Creation Hangs or Times Out

**Symptoms:**
```bash
kubectl apply -f redb.yaml
# Hangs for 30 seconds, then times out
```

**Diagnosis:**
```bash
# Check if webhook is reachable
kubectl get validatingwebhookconfiguration redb-admission -o yaml

# Check operator pod status
kubectl get pods -n redis-enterprise -l name=redis-enterprise-operator

# Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator
```

**Solution:**
- Ensure operator pod is running and healthy
- Check network policies allow webhook traffic
- Verify service endpoints are correct

### Issue: Webhook Certificate Expired

**Symptoms:**
```
Error: x509: certificate has expired
```

**Solution:**
```bash
# Delete and recreate the webhook (operator will regenerate certs)
kubectl delete validatingwebhookconfiguration redb-admission

# Restart operator to regenerate
kubectl rollout restart deployment redis-enterprise-operator -n redis-enterprise
```

---

## 📚 Related Documentation

- [Operator Installation](../README.md)
- [REDB Examples](../../deployments/single-region/)
- [Best Practices](../../best-practices/README.md)

