# Vault in Cluster - Quick Start

**Note:** This quick start uses manual steps instead of automation scripts for better learning and troubleshooting. For detailed explanations, see [README.md](./README.md).

## 🚀 Quick Deployment Steps

### 1️⃣ Deploy Vault

```bash
# Add Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault with HA
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --values 01-vault-helm-values.yaml

# Wait for pods (will be 0/1 - sealed)
kubectl get pods -n vault -w
```

**Expected:** vault-0, vault-1, vault-2 (0/1 Running - sealed), vault-agent-injector (1/1 Running)

### 2️⃣ Initialize and Unseal Vault

```bash
# Initialize Vault (only on vault-0)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# ⚠️ IMPORTANT: Save vault-keys.json in a secure location!

# Extract keys
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Unseal all Vault pods
for pod in vault-0 vault-1 vault-2; do
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_1
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_2
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_3
done

# Verify all pods are 1/1 Running
kubectl get pods -n vault
```

### 3️⃣ Configure Vault

```bash
# Login to Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Enable KV v2 secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable -version=2 -path=secret kv

# Enable Kubernetes authentication
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure Kubernetes auth
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy for Redis Enterprise
kubectl exec -n vault vault-0 -- vault policy write redisenterprise-redis-enterprise - <<EOF
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF

# Create roles
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/redis-enterprise-operator-redis-enterprise \
  bound_service_account_names=redis-enterprise-operator \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/redis-enterprise-rec-redis-enterprise \
  bound_service_account_names=rec \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h
```

### 4️⃣ Deploy Redis Enterprise Operator

```bash
# Create namespace
kubectl create namespace redis-enterprise

# Apply Operator ConfigMap
kubectl apply -f 03-operator-config.yaml

# Install Operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/redis-enterprise-cluster_rhel_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml

# Wait for operator (will be 1/2 until next step)
kubectl get pods -n redis-enterprise -w
```

### 5️⃣ Generate and Store admission-tls Certificate

```bash
# Wait for operator to start
sleep 30

# Get operator pod name
OPERATOR_POD=$(kubectl get pod -l name=redis-enterprise-operator -n redis-enterprise -o jsonpath='{.items[0].metadata.name}')

# Generate admission-tls certificate
kubectl exec -n redis-enterprise $OPERATOR_POD -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer 2>/dev/null | tail -4 > admission-tls.json

# Extract certificate and key
CERT=$(cat admission-tls.json | jq -r .cert)
PRIVATE_KEY=$(cat admission-tls.json | jq -r .privateKey)

# Store in Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put secret/redisenterprise-redis-enterprise/admission-tls \
  cert="$CERT" \
  privateKey="$PRIVATE_KEY"

# Restart operator
kubectl rollout restart deployment/redis-enterprise-operator -n redis-enterprise

# Verify operator is now 2/2
kubectl get pods -n redis-enterprise
```

**Expected:** redis-enterprise-operator-xxx (2/2 Running)

### 6️⃣ Store Cluster Credentials

```bash
# Store cluster credentials in Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put \
  secret/redisenterprise-redis-enterprise/rec \
  username=demo@redislabs.com \
  password='MySecurePassword123!'

# Verify secret was stored
kubectl exec -n vault vault-0 -- vault kv get secret/redisenterprise-redis-enterprise/rec
```

### 7️⃣ Deploy REC and Database

```bash
# Deploy Redis Enterprise Cluster
kubectl apply -f 04-rec-with-vault.yaml

# Wait for REC to be ready
kubectl get rec -n redis-enterprise -w
```

**Expected:** rec (Running)

```bash
# Deploy Database
kubectl apply -f 05-database-with-vault.yaml

# Verify database
kubectl get redb -n redis-enterprise
```

**Expected:** my-database (active)

## ✅ Verification

```bash
# 1. Verify Vault pods
kubectl get pods -n vault
# Expected: vault-0, vault-1, vault-2 (1/1 Running)

# 2. Verify Operator
kubectl get pods -n redis-enterprise
# Expected: redis-enterprise-operator-xxx (2/2 Running)

# 3. Verify REC
kubectl get rec -n redis-enterprise
# Expected: rec (Running)

# 4. Verify Database
kubectl get redb -n redis-enterprise
# Expected: my-database (active)

# 5. Verify secrets in Vault
kubectl exec -n vault vault-0 -- vault kv list secret/redisenterprise-redis-enterprise/
# Expected: admission-tls, rec
```

## 🔍 Quick Troubleshooting

### Vault Pods 0/1 (Sealed)

**Cause:** Vault was not unsealed after restart

**Solution:**
```bash
# Unseal manually
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')

for pod in vault-0 vault-1 vault-2; do
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_1
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_2
  kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_3
done
```

### Operator 1/2

**Cause:** admission-tls secret missing in Vault

**Solution:**
```bash
# Check admission container logs
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20

# Re-run Step 5 to generate and store admission-tls
```

### REC Pods Stuck in Init

**Cause:** Vault Agent cannot authenticate

**Solution:**
```bash
# Check Vault Agent logs
kubectl logs -n redis-enterprise rec-0 -c vault-agent-init

# Verify secret exists in Vault
kubectl exec -n vault vault-0 -- vault kv get secret/redisenterprise-redis-enterprise/rec

# Verify Kubernetes auth role exists
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/redis-enterprise-rec-redis-enterprise
```

## 🎯 Next Steps

- Configure backup with Velero
- Implement auto-unseal with Cloud KMS
- Configure Vault audit logs
- Rotate secrets periodically
- Set up monitoring for Vault

## 📚 Full Documentation

See [README.md](./README.md) for detailed documentation with expected outputs and comprehensive troubleshooting.

