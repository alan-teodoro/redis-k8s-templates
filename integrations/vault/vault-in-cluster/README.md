# Vault in Cluster - Redis Enterprise Integration

Complete deployment of HashiCorp Vault inside Kubernetes and integration with Redis Enterprise.

## 📋 Overview

This implementation installs Vault directly in the Kubernetes cluster using Helm, configuring:
- Vault with HA (3 replicas) using Raft storage
- Vault Agent Injector for automatic secret injection
- Complete integration with Redis Enterprise Operator
- Everything via Kubernetes internal DNS (no external IPs)

## 🎯 Advantages

- ✅ **Simple setup**: Everything via `kubectl` and `helm`
- ✅ **Native HA**: StatefulSet with 3 replicas
- ✅ **Minimal latency**: Internal cluster network
- ✅ **No Security Groups**: No firewall configuration needed
- ✅ **Reduced cost**: Uses existing cluster nodes
- ✅ **Automated maintenance**: Kubernetes manages everything

## 📁 Files

```
vault-in-cluster/
├── README.md                          # This file
├── 01-vault-helm-values.yaml          # Vault Helm values
├── 03-operator-config.yaml            # Operator ConfigMap
├── 04-rec-with-vault.yaml             # REC with Vault
└── 05-database-with-vault.yaml        # Database with Vault
```

## 🚀 Step-by-Step Deployment

### Step 1: Deploy Vault

```bash
# Add Vault Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault with HA
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.ha.raft.enabled=true" \
  --set "injector.enabled=true" \
  --set "ui.enabled=true"

# Verify pods
kubectl get pods -n vault
# Expected: vault-0, vault-1, vault-2 (0/1 Running - sealed)
#           vault-agent-injector-xxx (1/1 Running)
```

**Expected output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 0/1     Running   0          30s
vault-1                                 0/1     Running   0          30s
vault-2                                 0/1     Running   0          30s
vault-agent-injector-5d8c9b9f4b-xxxxx   1/1     Running   0          30s
```

### Step 2: Initialize and Unseal Vault

```bash
# Initialize Vault (only on vault-0)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# ⚠️ IMPORTANT: Save vault-keys.json in a secure location!
```

**Expected output:**
```json
{
  "unseal_keys_b64": ["key1...", "key2...", "key3...", "key4...", "key5..."],
  "unseal_keys_hex": ["...", "...", "...", "...", "..."],
  "unseal_shares": 5,
  "unseal_threshold": 3,
  "recovery_keys_b64": [],
  "recovery_keys_hex": [],
  "recovery_keys_shares": 0,
  "recovery_keys_threshold": 0,
  "root_token": "hvs.xxxxxxxxxxxxx"
}
```

```bash
# Extract keys
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Unseal vault-0
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3
```

**Expected output after each unseal command:**
```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  true    # false after 3rd unseal
Unseal Progress         1/3     # 2/3, then 3/3
...
```

```bash
# Unseal vault-1
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_3

# Unseal vault-2
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_3

# Verify status
kubectl get pods -n vault
# Expected: vault-0, vault-1, vault-2 (1/1 Running)
```

### Step 3: Configure Kubernetes Authentication

```bash
# Login to Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
```

**Expected output:**
```
Success! You are now authenticated.
```

```bash
# Enable KV v2 secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable -version=2 -path=secret kv
```

**Expected output:**
```
Success! Enabled the kv secrets engine at: secret/
```

```bash
# Enable Kubernetes authentication
kubectl exec -n vault vault-0 -- vault auth enable kubernetes
```

**Expected output:**
```
Success! Enabled kubernetes auth method at: kubernetes/
```

```bash
# Configure Kubernetes auth (uses internal DNS!)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"
```

**Expected output:**
```
Success! Data written to: auth/kubernetes/config
```

```bash
# Create policy for Redis Enterprise
kubectl exec -n vault vault-0 -- vault policy write redisenterprise-redis-enterprise - <<EOF
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF
```

**Expected output:**
```
Success! Uploaded policy: redisenterprise-redis-enterprise
```

```bash
# Create roles for operator and REC
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

**Expected output:**
```
Success! Data written to: auth/kubernetes/role/redis-enterprise-operator-redis-enterprise
Success! Data written to: auth/kubernetes/role/redis-enterprise-rec-redis-enterprise
```

### Step 4: Deploy Redis Enterprise Operator

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

**Expected output:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
redis-enterprise-operator-xxxxxxxxx-xxxxx   1/2     Running   0          30s
```

### Step 5: Generate and Store admission-tls Certificate

```bash
# Wait for operator to start
sleep 30

# Get operator pod name
OPERATOR_POD=$(kubectl get pod -l name=redis-enterprise-operator -n redis-enterprise -o jsonpath='{.items[0].metadata.name}')

# Generate admission-tls certificate
kubectl exec -n redis-enterprise $OPERATOR_POD -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer 2>/dev/null | tail -4 > admission-tls.json
```

**Expected output in admission-tls.json:**
```json
{
  "cert": "LS0tLS1CRUdJTi...",
  "privateKey": "LS0tLS1CRUdJTi..."
}
```

```bash
# Extract certificate and key
CERT=$(cat admission-tls.json | jq -r .cert)
PRIVATE_KEY=$(cat admission-tls.json | jq -r .privateKey)

# Store in Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put secret/redisenterprise-redis-enterprise/admission-tls \
  cert="$CERT" \
  privateKey="$PRIVATE_KEY"
```

**Expected output:**
```
====== Secret Path ======
secret/data/redisenterprise-redis-enterprise/admission-tls

======= Metadata =======
Key                Value
---                -----
created_time       2026-01-10T...
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

```bash
# Restart operator to pick up the secret
kubectl rollout restart deployment/redis-enterprise-operator -n redis-enterprise

# Verify operator is now 2/2
kubectl get pods -n redis-enterprise -w
```

**Expected output:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
redis-enterprise-operator-xxxxxxxxx-xxxxx   2/2     Running   0          1m
```

### Step 6: Create Cluster Credentials

```bash
# Store cluster credentials in Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put secret/redisenterprise-redis-enterprise/rec \
  username=demo@redislabs.com \
  password='MySecurePassword123!'
```

**Expected output:**
```
====== Secret Path ======
secret/data/redisenterprise-redis-enterprise/rec

======= Metadata =======
Key                Value
---                -----
created_time       2026-01-10T...
version            1
```

```bash
# Verify secret was stored
kubectl exec -n vault vault-0 -- vault kv get secret/redisenterprise-redis-enterprise/rec
```

**Expected output:**
```
====== Data ======
Key         Value
---         -----
password    MySecurePassword123!
username    demo@redislabs.com
```

### Step 7: Deploy REC and Database

```bash
# Deploy Redis Enterprise Cluster
kubectl apply -f 04-rec-with-vault.yaml

# Wait for REC to be ready
kubectl get rec -n redis-enterprise -w
```

**Expected output:**
```
NAME   NODES   VERSION      STATE     SPEC STATUS   LICENSE STATE   SHARDS LIMIT   LICENSE EXPIRATION DATE   AGE
rec    3       7.4.2-54     Running   Valid         Valid           4              2025-12-31                 2m
```

```bash
# Deploy Database
kubectl apply -f 05-database-with-vault.yaml

# Verify database
kubectl get redb -n redis-enterprise
```

**Expected output:**
```
NAME          STATUS   SPEC STATUS   AGE
my-database   active   Valid         30s
```

## 🔍 Verification

### 1. Verify Vault Pods

```bash
kubectl get pods -n vault
```

**Expected output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 1/1     Running   0          10m
vault-1                                 1/1     Running   0          10m
vault-2                                 1/1     Running   0          10m
vault-agent-injector-5d8c9b9f4b-xxxxx   1/1     Running   0          10m
```

### 2. Verify Operator

```bash
kubectl get pods -n redis-enterprise
```

**Expected output:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
redis-enterprise-operator-xxxxxxxxx-xxxxx   2/2     Running   0          5m
```

### 3. Verify Admission Container Logs

```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20
```

**Expected output should contain:**
```
new Vault token was created
TLS key successfully retrieved from Vault
```

### 4. Verify Secrets Injected in REC Pods

```bash
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  cat /vault/secrets/rec.json
```

**Expected output:**
```json
{"password": "MySecurePassword123!", "username": "demo@redislabs.com"}
```

### 5. Verify Secrets in Vault

```bash
kubectl exec -n vault vault-0 -- vault kv list secret/redisenterprise-redis-enterprise/
```

**Expected output:**
```
Keys
----
admission-tls
rec
```

## 🔧 Differences vs External Vault

| Aspect | External Vault | Vault in Cluster |
|---------|---------------|------------------|
| **VAULT_SERVER_FQDN** | Public IP or DNS | `vault.vault.svc.cluster.local` |
| **Vault Agent Injector** | Need to configure `externalVaultAddr` | Automatic |
| **CA Certificate** | Need to copy manually | Managed by K8s |
| **Kubernetes Auth** | Need to configure `kubernetes_host` with external URL | Uses `https://kubernetes.default.svc:443` |
| **Security Groups** | Required | Not required |
| **Latency** | External network | Internal network |
| **Setup Complexity** | Higher (network config) | Lower (all in K8s) |

## ⚠️ Troubleshooting

### Vault Pods Stay 0/1 (Sealed)

**Cause:** Vault was not unsealed after restart

**Solution:**
```bash
# Unseal each pod with 3 keys
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3

# Repeat for vault-1 and vault-2
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_3

kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_3
```

### Operator Stays 1/2

**Cause:** Secret `admission-tls` does not exist in Vault

**Solution:** Re-run Step 5 to generate and store admission-tls certificate

### REC Pods Stuck in Init

**Cause:** Vault Agent cannot authenticate

**Check logs:**
```bash
kubectl logs -n redis-enterprise rec-0 -c vault-agent-init
```

**Look for:** `authentication successful`

**If authentication fails, verify:**
1. Kubernetes auth is enabled in Vault
2. Role `redis-enterprise-rec-redis-enterprise` exists
3. ServiceAccount `rec` exists in namespace `redis-enterprise`

## 📚 Additional Resources

- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide)
- [Vault HA with Raft](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)
- [Redis Enterprise Vault Integration](https://redis.io/blog/kubernetes-secret/)

## 🔒 Security Best Practices

**⚠️ IMPORTANT:**
- Save `vault-keys.json` in a secure location (e.g., 1Password, AWS Secrets Manager)
- **NEVER** commit `vault-keys.json` to Git
- In production, consider using auto-unseal with AWS KMS/GCP KMS/Azure Key Vault
- Rotate the root token after initial configuration
- Enable audit logging in Vault
- Use separate Vault namespaces for different environments

## 🎯 Next Steps

- Configure automatic backup with Velero
- Implement auto-unseal with Cloud KMS
- Configure Vault audit logs
- Implement automatic secret rotation
- Set up monitoring and alerting for Vault
- Configure Vault snapshots for disaster recovery

