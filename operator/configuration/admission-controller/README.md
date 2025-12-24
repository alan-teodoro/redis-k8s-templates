# Redis Enterprise Admission Controller

The admission controller dynamically validates Redis Enterprise Database (REDB) resources configured by the operator. It is **strongly recommended** to enable the admission controller on your Redis Enterprise Cluster.

## 📋 Overview

The admission controller:
- ✅ Validates REDB configurations before they are applied
- ✅ Prevents invalid database configurations
- ✅ Provides immediate feedback on configuration errors
- ✅ Only needs to be configured **once per operator deployment**

---

## 🚀 Quick Setup

### Prerequisites

- Redis Enterprise Operator installed
- Redis Enterprise Cluster (REC) deployed
- `kubectl` access to the cluster

---

### Step 1: Verify admission-tls Secret

The operator automatically creates the `admission-tls` secret during REC creation. Wait a few minutes after creating your REC, then verify:

```bash
kubectl get secret admission-tls -n redis-enterprise
```

**Expected output:**
```
NAME            TYPE     DATA   AGE
admission-tls   Opaque   2      2m43s
```

If the secret doesn't exist, wait a few more minutes or check the operator logs.

---

### Step 2: Create ValidatingWebhookConfiguration

Apply the webhook configuration:

```bash
kubectl apply -f webhook.yaml
```

This creates a Kubernetes `ValidatingWebhookConfiguration` that intercepts REDB resource requests.

---

### Step 3: Patch Webhook with Certificate

Extract the certificate from the secret and patch the webhook:

```bash
# Get the certificate
CERT=$(kubectl get secret admission-tls -n redis-enterprise -o jsonpath='{.data.cert}')

# Patch the webhook
kubectl patch ValidatingWebhookConfiguration redis-enterprise-admission \
  --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/clientConfig/caBundle', 'value':'${CERT}'}]"
```

---

### Step 4: Verify Admission Controller

Test the admission controller by applying an invalid REDB resource:

```bash
kubectl apply -f test-invalid-redb.yaml
```

**Expected output:**
```
Error from server: admission webhook "redisenterprise.admission.redislabs" denied the request: 
eviction_policy: u'illegal' is not one of [u'volatile-lru', u'volatile-ttl', u'volatile-random', 
u'allkeys-lru', u'allkeys-random', u'noeviction', u'volatile-lfu', u'allkeys-lfu']
```

If you see this error, the admission controller is working correctly! ✅

---

## 🔧 Advanced Configuration

### Limit Webhook to Specific Namespaces

By default, the webhook intercepts requests from **all namespaces**. To limit it to specific namespaces:

#### 1. Label the namespace

```bash
kubectl label namespace redis-enterprise namespace-name=redis-enterprise
```

#### 2. Patch the webhook with namespace selector

```bash
kubectl patch ValidatingWebhookConfiguration redis-enterprise-admission \
  --type='json' -p='[{
    "op": "add",
    "path": "/webhooks/0/namespaceSelector",
    "value": {
      "matchLabels": {
        "namespace-name": "redis-enterprise"
      }
    }
  }]'
```

---

## 🔍 Troubleshooting

### Secret not found

```bash
# Check if REC is running
kubectl get rec -n redis-enterprise

# Check operator logs
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator
```

### Webhook not working

```bash
# Check webhook configuration
kubectl get validatingwebhookconfigurations redis-enterprise-admission -o yaml

# Verify certificate is set
kubectl get validatingwebhookconfigurations redis-enterprise-admission \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d
```

### Permission errors

Ensure you have cluster-admin permissions to create ValidatingWebhookConfigurations.

---

## 📚 Additional Resources

- [Redis Enterprise Admission Controller Documentation](https://redis.io/docs/latest/operate/kubernetes/deployment/quick-start/#enable-the-admission-controller)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [ValidatingWebhookConfiguration Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#validatingwebhookconfiguration-v1-admissionregistration-k8s-io)

