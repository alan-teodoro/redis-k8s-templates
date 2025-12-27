# Vault Server Configuration Commands

Complete guide for configuring HashiCorp Vault server to integrate with Redis Enterprise on Kubernetes.

---

## 📋 Prerequisites

- Vault server v1.15.2+ installed and running with TLS
- Vault initialized and unsealed
- Root token or admin access
- Network connectivity from Kubernetes cluster to Vault

---

## 🔧 Vault Server Setup

### Step 1: Set Vault Environment Variables

On the Vault server or your local machine with Vault CLI:

```bash
# Set Vault address
export VAULT_ADDR='https://<VAULT_SERVER_IP>:8200'

# For self-signed certificates (testing only)
export VAULT_SKIP_VERIFY=true

# Login with root token
vault login <ROOT_TOKEN>
```

---

## 🗄️ Enable Secret Engine

### Enable KV v2 Secret Engine

```bash
# Enable KV version 2 secret engine at path 'secret'
vault secrets enable -path=secret kv-v2

# Verify
vault secrets list
```

Expected output:
```
Path          Type         Description
----          ----         -----------
secret/       kv           n/a
```

---

## 🔐 Configure Kubernetes Authentication

### Step 1: Get Kubernetes Information

On your local machine (where kubectl is configured):

```bash
# 1. Get Kubernetes API server endpoint
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
# Example output: https://ABC123.gr7.us-east-1.eks.amazonaws.com

# 2. Extract Kubernetes CA certificate
kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.certificate-authority-data}' \
  | base64 -d > k8s-ca.crt

# 3. Create service account for Vault authentication
kubectl create serviceaccount vault-auth -n redis-enterprise

# 4. Create cluster role binding
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=redis-enterprise:vault-auth

# 5. Generate service account token (valid for 1 year)
kubectl create token vault-auth -n redis-enterprise \
  --duration=8760h > vault-reviewer-token.txt
```

### Step 2: Enable Kubernetes Auth Method

On the Vault server:

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Verify
vault auth list
```

### Step 3: Configure Kubernetes Auth Method

Copy the files (`k8s-ca.crt` and `vault-reviewer-token.txt`) to the Vault server, then:

```bash
# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="<K8S_API_SERVER_ENDPOINT>" \
  kubernetes_ca_cert=@k8s-ca.crt \
  token_reviewer_jwt=@vault-reviewer-token.txt

# Example:
# vault write auth/kubernetes/config \
#   kubernetes_host="https://ABC123.gr7.us-east-1.eks.amazonaws.com" \
#   kubernetes_ca_cert=@k8s-ca.crt \
#   token_reviewer_jwt=@vault-reviewer-token.txt
```

Verify configuration:

```bash
vault read auth/kubernetes/config
```

---

## 📜 Create Policies

### Policy for Redis Enterprise Operator

```bash
vault policy write redisenterprise-redis-enterprise - <<EOF
# Allow full access to Redis Enterprise secrets
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow listing secret metadata
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF
```

Verify policy:

```bash
vault policy read redisenterprise-redis-enterprise
```

---

## 🎭 Create Vault Roles

### Role for Redis Enterprise Operator

```bash
vault write auth/kubernetes/role/redis-enterprise-operator-redis-enterprise \
  bound_service_account_names="redis-enterprise-operator" \
  bound_service_account_namespaces="redis-enterprise" \
  policies="redisenterprise-redis-enterprise" \
  ttl=1h
```

### Role for Redis Enterprise Cluster (REC)

```bash
vault write auth/kubernetes/role/redis-enterprise-rec-redis-enterprise \
  bound_service_account_names="rec" \
  bound_service_account_namespaces="redis-enterprise" \
  policies="redisenterprise-redis-enterprise" \
  ttl=1h
```

Verify roles:

```bash
# List roles
vault list auth/kubernetes/role

# Read operator role
vault read auth/kubernetes/role/redis-enterprise-operator-redis-enterprise

# Read REC role
vault read auth/kubernetes/role/redis-enterprise-rec-redis-enterprise
```

---

## 🔑 Store Initial Secrets

### Store Cluster Credentials

```bash
# Store Redis Enterprise cluster admin credentials
vault kv put secret/redisenterprise-redis-enterprise/rec \
  username=admin@redis.com \
  password=RedisAdmin123!
```

Verify:

```bash
vault kv get secret/redisenterprise-redis-enterprise/rec
```

Expected output:
```
====== Data ======
Key         Value
---         -----
password    RedisAdmin123!
username    admin@redis.com
```

### Store Database Password

```bash
# Store database password
vault kv put secret/redisenterprise-redis-enterprise/test-db \
  password=TestDB123!
```

Verify:

```bash
vault kv get secret/redisenterprise-redis-enterprise/test-db
```

---

## 📋 Summary Checklist

After completing these steps, verify:

- [ ] KV v2 secret engine enabled at `secret/`
- [ ] Kubernetes auth method enabled
- [ ] Kubernetes auth configured with K8s API endpoint and CA cert
- [ ] Policy `redisenterprise-redis-enterprise` created
- [ ] Role `redis-enterprise-operator-redis-enterprise` created
- [ ] Role `redis-enterprise-rec-redis-enterprise` created
- [ ] Cluster credentials stored at `secret/redisenterprise-redis-enterprise/rec`
- [ ] Database password stored at `secret/redisenterprise-redis-enterprise/test-db`

---

## 🧪 Test Vault Configuration

### Test Policy Permissions

```bash
# Test read access
vault kv get secret/redisenterprise-redis-enterprise/rec

# Test list access
vault kv list secret/redisenterprise-redis-enterprise
```

### Test Kubernetes Auth (from K8s cluster)

Create a test pod to verify Kubernetes auth:

```bash
kubectl run vault-test --image=vault:1.15.2 -it --rm -- sh
```

Inside the pod:

```bash
# Set Vault address
export VAULT_ADDR='https://<VAULT_SERVER_IP>:8200'
export VAULT_SKIP_VERIFY=true

# Get service account token
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Authenticate with Vault
vault write auth/kubernetes/login \
  role=redis-enterprise-operator-redis-enterprise \
  jwt=$SA_TOKEN
```


