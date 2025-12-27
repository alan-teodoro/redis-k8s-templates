# HashiCorp Vault Integration with Redis Enterprise

Integrate HashiCorp Vault as the centralized secret management system for Redis Enterprise on Kubernetes.

---

## 📋 Overview

This integration replaces Kubernetes secrets with HashiCorp Vault for all Redis Enterprise secrets, providing:
- **Enhanced security**: Centralized secret management
- **Secret rotation**: Advanced lifecycle management
- **Audit logging**: Complete secret access tracking
- **Compliance**: Enterprise-grade secrets management

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HashiCorp Vault Server                   │
│                  (External VM or K8s Pod)                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ KV v2 Secret Engine: secret/                         │  │
│  │  └── redisenterprise-redis-enterprise/               │  │
│  │      ├── admission-tls                               │  │
│  │      ├── rec (cluster credentials)                   │  │
│  │      └── test-db (database password)                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Kubernetes Auth Method: auth/kubernetes              │  │
│  │  ├── Role: redis-enterprise-operator-redis-enterprise│ │
│  │  └── Role: redis-enterprise-rec-redis-enterprise     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ HTTPS (port 8200)
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                  Kubernetes Cluster                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Vault Agent Injector (namespace: vault)              │  │
│  │  - Injects Vault secrets into pods                   │  │
│  │  - Manages authentication with Vault                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Redis Enterprise Operator (namespace: redis-enterprise)│ │
│  │  - Reads ConfigMap: operator-environment-config      │  │
│  │  - Authenticates to Vault via K8s auth               │  │
│  │  - Retrieves secrets from Vault                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Redis Enterprise Cluster (REC)                       │  │
│  │  - Uses Vault for cluster credentials                │  │
│  │  - Vault annotations in pod spec                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Directory Structure

```
integrations/vault/
├── README.md                           # This file
├── 01-vault-agent-injector.yaml        # Vault Agent Injector installation
├── 02-vault-ca-cert.yaml               # Vault CA certificate (template)
├── 03-operator-environment-config.yaml # Operator Vault configuration
├── 04-rec-vault.yaml                   # REC with Vault integration
├── 05-redb-vault.yaml                  # REDB with Vault integration
└── vault-commands.md                   # Vault server configuration commands
```

---

## ⚙️ Prerequisites

### Vault Server Requirements
- HashiCorp Vault v1.15.2+ running with TLS
- Network connectivity from Kubernetes cluster to Vault (port 8200)
- Vault server can be:
  - External VM in same VPC (recommended for this guide)
  - Vault running inside Kubernetes
  - Managed Vault service (HCP Vault)

### Kubernetes Requirements
- Kubernetes 1.23+
- Redis Enterprise Operator NOT yet installed (will be configured for Vault)
- Cluster admin access
- `kubectl` configured

### Information Needed
- Vault server FQDN or IP address
- Vault CA certificate file
- Vault root token (for initial configuration)

---

## 🚀 Installation

### Step 1: Configure Vault Server

**See:** [vault-commands.md](vault-commands.md) for complete Vault server configuration.

Summary of what needs to be configured on Vault:
1. Enable KV v2 secret engine
2. Enable Kubernetes auth method
3. Create policies for Redis Enterprise
4. Create Vault roles for operator and cluster
5. Store initial secrets (admission-tls, cluster credentials)

### Step 2: Install Vault Agent Injector

Install the Vault Agent Injector in your Kubernetes cluster:

```bash
kubectl apply -f 01-vault-agent-injector.yaml
```

Wait for the injector to be ready:

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=vault-agent-injector \
  -n vault \
  --timeout=300s
```

### Step 3: Create Vault CA Certificate Secret

Copy the Vault CA certificate to your local machine, then create the secret:

```bash
# Replace <vault-ca.pem> with your Vault CA certificate file
kubectl create secret generic vault-ca-cert \
  --namespace redis-enterprise \
  --from-file=vault.ca=<vault-ca.pem>
```

Or use the template (edit with your certificate):

```bash
# Edit the file and replace <BASE64_ENCODED_CA_CERT>
kubectl apply -f 02-vault-ca-cert.yaml
```

### Step 4: Create Operator Environment ConfigMap

Edit `03-operator-environment-config.yaml` and update:
- `VAULT_SERVER_FQDN`: Your Vault server hostname or IP

```bash
kubectl apply -f 03-operator-environment-config.yaml
```

### Step 5: Install Redis Enterprise Operator

Install the operator with Vault configuration:

```bash
# Add Helm repository
helm repo add redis https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/helm-releases
helm repo update

# Install operator with environment config
helm install redis-enterprise-operator redis/redis-enterprise-operator \
  --namespace redis-enterprise \
  --create-namespace \
  --set extraEnvFrom[0].configMapRef.name=operator-environment-config
```

**⚠️ Important:** The operator pod will not be ready until the admission controller secret is stored in Vault (next step).

### Step 6: Generate and Store Admission Controller Secret

Generate the admission controller TLS certificate and store it in Vault:

```bash
# Get operator pod name
OPERATOR_POD=$(kubectl get pod -n redis-enterprise \
  -l name=redis-enterprise-operator \
  -o jsonpath='{.items[0].metadata.name}')

# Generate TLS certificate
kubectl exec -it $OPERATOR_POD -n redis-enterprise \
  -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer | tail -4 > admission-tls.json
```

On the Vault server, store the certificate:

```bash
# Copy the file to Vault server (if needed)
# Then run on Vault server:
vault kv put secret/redisenterprise-redis-enterprise/admission-tls @admission-tls.json
```

Verify the operator pod becomes ready:

```bash
kubectl wait --for=condition=ready pod \
  -l name=redis-enterprise-operator \
  -n redis-enterprise \
  --timeout=300s
```

### Step 7: Deploy Redis Enterprise Cluster

Deploy the REC with Vault integration:

```bash
kubectl apply -f 04-rec-vault.yaml
```

Wait for the cluster to be ready:

```bash
kubectl wait --for=condition=Ready rec/rec \
  -n redis-enterprise \
  --timeout=600s
```

### Step 8: Deploy Redis Enterprise Database

Deploy a database with Vault-managed password:

```bash
kubectl apply -f 05-redb-vault.yaml
```

Wait for the database to be ready:

```bash
kubectl wait --for=condition=Ready redb/test-db \
  -n redis-enterprise \
  --timeout=300s
```

---

## ✅ Verification

### Verify Vault Integration

Check that secrets are being retrieved from Vault:

```bash
# Check operator logs for Vault authentication
kubectl logs -n redis-enterprise \
  -l name=redis-enterprise-operator \
  -c redis-enterprise-operator \
  --tail=50 | grep -i vault

# Should see successful Vault authentication messages
```

### Verify REC Status

```bash
kubectl get rec -n redis-enterprise

# Should show:
# NAME   NODES   VERSION   STATE     SPEC STATUS   LICENSE STATE   AGE
# rec    3       8.0.6-8   Running   Valid         Valid           5m
```

### Verify Database Status

```bash
kubectl get redb -n redis-enterprise

# Should show:
# NAME      STATUS   SPEC STATUS   AGE
# test-db   active   Valid         2m
```

### Test Database Connection

```bash
# Get database password from Vault (on Vault server)
vault kv get -field=password secret/redisenterprise-redis-enterprise/test-db

# Get database service
kubectl get svc test-db -n redis-enterprise

# Test connection (from within cluster or via port-forward)
redis-cli -h test-db.redis-enterprise.svc.cluster.local -p 12000 \
  --tls --insecure \
  -a <PASSWORD_FROM_VAULT> \
  PING
# Expected: PONG
```

---

## 🔧 Configuration Details

### Secrets Managed by Vault

When Vault integration is enabled, the following secrets are retrieved from Vault:

| Secret Type | Vault Path | Description |
|-------------|------------|-------------|
| Admission TLS | `secret/data/redisenterprise-redis-enterprise/admission-tls` | Operator admission controller certificate |
| Cluster Credentials | `secret/data/redisenterprise-redis-enterprise/rec` | REC admin username and password |
| Database Password | `secret/data/redisenterprise-redis-enterprise/test-db` | Database password |

### Vault Path Structure

All secrets follow this pattern:

```
<VAULT_SECRET_ROOT>/data/<VAULT_SECRET_PREFIX>/<secret-name>
```

Default configuration:
- `VAULT_SECRET_ROOT`: `secret`
- `VAULT_SECRET_PREFIX`: `redisenterprise-redis-enterprise`

Example paths:
- `secret/data/redisenterprise-redis-enterprise/admission-tls`
- `secret/data/redisenterprise-redis-enterprise/rec`
- `secret/data/redisenterprise-redis-enterprise/test-db`

---

## 🔍 Troubleshooting

### Operator Pod Not Ready

**Symptoms:** Operator pod stuck in `Pending` or `CrashLoopBackOff`

**Causes and Solutions:**

1. **Missing admission-tls secret in Vault:**
   ```bash
   # Verify secret exists (on Vault server)
   vault kv get secret/redisenterprise-redis-enterprise/admission-tls
   ```

2. **Vault CA certificate issues:**
   ```bash
   # Verify secret exists
   kubectl get secret vault-ca-cert -n redis-enterprise

   # Check certificate content
   kubectl get secret vault-ca-cert -n redis-enterprise \
     -o jsonpath='{.data.vault\.ca}' | base64 -d
   ```

3. **Network connectivity to Vault:**
   ```bash
   # Test from operator pod
   kubectl exec -it <operator-pod> -n redis-enterprise \
     -c redis-enterprise-operator -- \
     curl -k https://<VAULT_FQDN>:8200/v1/sys/health
   ```

### Authentication Failures

**Symptoms:** `Failed to authenticate with Vault` in operator logs

**Solutions:**

1. **Verify Vault role configuration (on Vault server):**
   ```bash
   vault read auth/kubernetes/role/redis-enterprise-operator-redis-enterprise
   ```

2. **Check service account:**
   ```bash
   kubectl get serviceaccount redis-enterprise-operator -n redis-enterprise
   ```

### Secret Retrieval Failures

**Symptoms:** `Failed to read Vault secret` errors

**Solutions:**

1. **Verify secret exists (on Vault server):**
   ```bash
   vault kv get secret/redisenterprise-redis-enterprise/<secret-name>
   ```

2. **Check policy permissions (on Vault server):**
   ```bash
   vault policy read redisenterprise-redis-enterprise
   ```

### REC Not Starting

**Symptoms:** REC pods not starting or stuck in `Pending`

**Solutions:**

1. **Verify cluster credentials in Vault (on Vault server):**
   ```bash
   vault kv get secret/redisenterprise-redis-enterprise/rec

   # Should have 'username' and 'password' fields
   ```

2. **Check REC events:**
   ```bash
   kubectl describe rec rec -n redis-enterprise
   ```

---

## 📚 Additional Resources

- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Redis Enterprise Vault Integration](https://redis.io/docs/latest/operate/kubernetes/security/hashicorp-vault/)
- [Vault Server Configuration Commands](vault-commands.md)

---

## 🔐 Security Best Practices

1. **Use TLS:** Always run Vault with TLS enabled
2. **Rotate secrets:** Implement regular secret rotation policies
3. **Audit logging:** Enable Vault audit logging for compliance
4. **Least privilege:** Grant minimum required permissions in Vault policies
5. **Token TTL:** Configure appropriate token TTL (minimum 1 hour recommended)
6. **Network policies:** Restrict network access to Vault server
7. **Backup Vault:** Implement regular Vault backup procedures

---

## 📝 Notes

- This integration is compatible with both Vault Community and Enterprise editions
- For Vault Enterprise with namespaces, add `VAULT_NAMESPACE` to the ConfigMap
- All secrets must be stored in Vault before deploying resources that reference them
- The operator caches secrets for 120 seconds by default (configurable via `VAULT_CACHE_SECRET_EXPIRATION_SECONDS`)



