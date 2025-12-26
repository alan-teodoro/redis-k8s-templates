# Redis Enterprise Admission Controller

Validates REDB resources before creation. **Recommended for production.**

---

## Setup

### 1. Verify Secret

```bash
kubectl get secret admission-tls -n redis-enterprise
```

### 2. Apply Webhook

```bash
kubectl apply -f webhook.yaml
```

### 3. Patch with Certificate

```bash
CERT=$(kubectl get secret admission-tls -n redis-enterprise -o jsonpath='{.data.cert}')

kubectl patch ValidatingWebhookConfiguration redis-enterprise-admission \
  --type='json' -p="[{'op': 'replace', 'path': '/webhooks/0/clientConfig/caBundle', 'value':'${CERT}'}]"
```

### 4. Test

```bash
kubectl apply -f test-invalid-redb.yaml
```

**Expected:** Error message from admission webhook

---

## Troubleshooting

```bash
# Check webhook
kubectl get validatingwebhookconfigurations redis-enterprise-admission

# Verify certificate
kubectl get validatingwebhookconfigurations redis-enterprise-admission \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d

# Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50
```

---

## References

- [Redis Admission Controller Docs](https://redis.io/docs/latest/operate/kubernetes/deployment/quick-start/#enable-the-admission-controller)
