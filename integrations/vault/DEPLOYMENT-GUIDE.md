# Complete Deployment Guide: Redis Enterprise with Vault Integration

Step-by-step guide to deploy Redis Enterprise on Kubernetes with HashiCorp Vault for secret management.

---

## 📋 Scenario

**Customer Environment:**
- HashiCorp Vault server running on external VM in same VPC
- Kubernetes cluster (EKS, AKS, GKE, or vanilla)
- Customer wants to use Vault for all Redis Enterprise secrets

**What We'll Deploy:**
1. Vault Agent Injector in Kubernetes
2. Redis Enterprise Operator (configured for Vault)
3. Redis Enterprise Cluster (3 nodes)
4. Redis Enterprise Database (with Vault-managed password)

---

## 🎯 Prerequisites Checklist

### Vault Server (Customer-Managed)
- [ ] Vault v1.15.2+ installed and running
- [ ] Vault accessible via HTTPS on port 8200
- [ ] Vault initialized and unsealed
- [ ] Root token or admin access available
- [ ] Network connectivity from K8s cluster to Vault

### Kubernetes Cluster
- [ ] Kubernetes 1.23+ or OpenShift 4.10+
- [ ] kubectl or oc CLI configured
- [ ] Cluster admin access
- [ ] Helm v3.x installed
- [ ] Storage class available

### Information Needed
- [ ] Vault server IP or FQDN: `_________________`
- [ ] Vault root token: `_________________`
- [ ] Vault CA certificate file: `_________________`
- [ ] Kubernetes API server endpoint: `_________________`

---

## 📝 Deployment Steps

### Phase 1: Configure Vault Server

**Location:** On Vault server or machine with Vault CLI access

#### 1.1. Set Vault Environment

```bash
export VAULT_ADDR='https://<VAULT_SERVER_IP>:8200'
export VAULT_SKIP_VERIFY=true  # For self-signed certs
vault login <ROOT_TOKEN>
```

#### 1.2. Enable Secret Engine

```bash
vault secrets enable -path=secret kv-v2
vault secrets list
```

#### 1.3. Get Kubernetes Information

**Location:** On your local machine with kubectl

```bash
# Get K8s API server
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

# Extract K8s CA certificate
kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.certificate-authority-data}' \
  | base64 -d > k8s-ca.crt

# Create service account for Vault
kubectl create namespace redis-enterprise
kubectl create serviceaccount vault-auth -n redis-enterprise
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=redis-enterprise:vault-auth

# Generate token (1 year validity)
kubectl create token vault-auth -n redis-enterprise \
  --duration=8760h > vault-reviewer-token.txt
```

#### 1.4. Configure Kubernetes Auth

**Location:** On Vault server (copy k8s-ca.crt and vault-reviewer-token.txt to Vault server first)

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure auth method
vault write auth/kubernetes/config \
  kubernetes_host="<K8S_API_SERVER_ENDPOINT>" \
  kubernetes_ca_cert=@k8s-ca.crt \
  token_reviewer_jwt=@vault-reviewer-token.txt

# Verify
vault read auth/kubernetes/config
```

#### 1.5. Create Policy

```bash
vault policy write redisenterprise-redis-enterprise - <<EOF
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF

# Verify
vault policy read redisenterprise-redis-enterprise
```

#### 1.6. Create Vault Roles

```bash
# Role for operator
vault write auth/kubernetes/role/redis-enterprise-operator-redis-enterprise \
  bound_service_account_names="redis-enterprise-operator" \
  bound_service_account_namespaces="redis-enterprise" \
  policies="redisenterprise-redis-enterprise" \
  ttl=1h

# Role for REC
vault write auth/kubernetes/role/redis-enterprise-rec-redis-enterprise \
  bound_service_account_names="rec" \
  bound_service_account_namespaces="redis-enterprise" \
  policies="redisenterprise-redis-enterprise" \
  ttl=1h

# Verify
vault list auth/kubernetes/role
```

#### 1.7. Store Initial Secrets

```bash
# Cluster credentials
vault kv put secret/redisenterprise-redis-enterprise/rec \
  username=admin@redis.com \
  password=RedisAdmin123!

# Database password
vault kv put secret/redisenterprise-redis-enterprise/test-db \
  password=TestDB123!

# Verify
vault kv get secret/redisenterprise-redis-enterprise/rec
vault kv get secret/redisenterprise-redis-enterprise/test-db
```

**✅ Phase 1 Complete:** Vault server is configured

---

### Phase 2: Configure Kubernetes

**Location:** On your local machine with kubectl

#### 2.1. Install Vault Agent Injector

```bash
# Add Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault Agent Injector
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "injector.enabled=true" \
  --set "server.enabled=false" \
  --set "injector.externalVaultAddr=https://<VAULT_SERVER_IP>:8200"

# Wait for ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=vault-agent-injector \
  -n vault \
  --timeout=300s
```

#### 2.2. Create Vault CA Certificate Secret

```bash
# Copy Vault CA certificate from Vault server
# Then create secret:
kubectl create secret generic vault-ca-cert \
  --namespace redis-enterprise \
  --from-file=vault.ca=<path-to-vault-ca.pem>

# Verify
kubectl get secret vault-ca-cert -n redis-enterprise
```

#### 2.3. Create Operator Environment ConfigMap

Edit `03-operator-environment-config.yaml` and update `VAULT_SERVER_FQDN`:

```bash
# Apply ConfigMap
kubectl apply -f integrations/vault/03-operator-environment-config.yaml

# Verify
kubectl get configmap operator-environment-config -n redis-enterprise
```

**✅ Phase 2 Complete:** Kubernetes is configured for Vault

---

### Phase 3: Deploy Redis Enterprise Operator

#### 3.1. Install Operator with Vault Configuration

```bash
# Add Redis Helm repository
helm repo add redis https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/helm-releases
helm repo update

# Install operator with Vault environment config
helm install redis-enterprise-operator redis/redis-enterprise-operator \
  --namespace redis-enterprise \
  --set extraEnvFrom[0].configMapRef.name=operator-environment-config
```

**⚠️ Note:** The operator pod will NOT be ready yet. This is expected.

#### 3.2. Generate and Store Admission Controller Secret

```bash
# Wait for operator pod to be created (may take 1-2 minutes)
sleep 60

# Get operator pod name
OPERATOR_POD=$(kubectl get pod -n redis-enterprise \
  -l name=redis-enterprise-operator \
  -o jsonpath='{.items[0].metadata.name}')

# Generate admission TLS certificate
kubectl exec -it $OPERATOR_POD -n redis-enterprise \
  -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer | tail -4 > admission-tls.json
```

**Location:** On Vault server (copy admission-tls.json to Vault server first)

```bash
# Store in Vault
vault kv put secret/redisenterprise-redis-enterprise/admission-tls @admission-tls.json

# Verify
vault kv get secret/redisenterprise-redis-enterprise/admission-tls
```

#### 3.3. Verify Operator is Ready

**Location:** Back on your local machine with kubectl

```bash
# Wait for operator to be ready (should succeed now)
kubectl wait --for=condition=ready pod \
  -l name=redis-enterprise-operator \
  -n redis-enterprise \
  --timeout=300s

# Check operator logs
kubectl logs -n redis-enterprise \
  -l name=redis-enterprise-operator \
  -c redis-enterprise-operator \
  --tail=50 | grep -i vault
```

**✅ Phase 3 Complete:** Operator is running with Vault integration

---

### Phase 4: Deploy Redis Enterprise Cluster

#### 4.1. Update Storage Class (if needed)

Edit `04-rec-vault.yaml` and update `storageClassName`:
- EKS: `gp3`
- GKE: `pd-ssd`
- AKS: `managed-csi-premium`
- Vanilla: Check with `kubectl get storageclass`

#### 4.2. Deploy REC

```bash
# Apply REC
kubectl apply -f integrations/vault/04-rec-vault.yaml

# Wait for cluster to be ready (may take 5-10 minutes)
kubectl wait --for=condition=Ready rec/rec \
  -n redis-enterprise \
  --timeout=600s

# Verify cluster status
kubectl get rec -n redis-enterprise
kubectl get pods -n redis-enterprise
```

**✅ Phase 4 Complete:** Redis Enterprise Cluster is running

---

### Phase 5: Deploy Redis Enterprise Database

#### 5.1. Deploy Database

```bash
# Apply REDB
kubectl apply -f integrations/vault/05-redb-vault.yaml

# Wait for database to be ready
kubectl wait --for=condition=Ready redb/test-db \
  -n redis-enterprise \
  --timeout=300s

# Verify database status
kubectl get redb -n redis-enterprise
kubectl get svc test-db -n redis-enterprise
```

**✅ Phase 5 Complete:** Database is running

---

### Phase 6: Test and Verify

#### 6.1. Get Database Password from Vault

**Location:** On Vault server

```bash
vault kv get -field=password secret/redisenterprise-redis-enterprise/test-db
```

#### 6.2. Test Database Connection

**Location:** On your local machine with kubectl

```bash
# Port-forward to database
kubectl port-forward svc/test-db 12000:12000 -n redis-enterprise &

# Test connection (in another terminal)
redis-cli -h localhost -p 12000 \
  --tls --insecure \
  -a TestDB123! \
  PING

# Expected output: PONG

# Stop port-forward
kill %1
```

#### 6.3. Verify Secrets are from Vault

```bash
# Check that NO Kubernetes secrets exist for passwords
kubectl get secrets -n redis-enterprise | grep -E "rec|test-db"

# Should NOT see secrets named 'rec' or 'test-db'
# Only vault-ca-cert should exist
```

**✅ Phase 6 Complete:** Deployment verified and tested

---

## 🎉 Deployment Complete!

You have successfully deployed Redis Enterprise with HashiCorp Vault integration.

### What Was Deployed:
- ✅ Vault Agent Injector in namespace `vault`
- ✅ Redis Enterprise Operator in namespace `redis-enterprise`
- ✅ Redis Enterprise Cluster (3 nodes) in namespace `redis-enterprise`
- ✅ Redis Enterprise Database `test-db` on port 12000

### Secrets Managed by Vault:
- ✅ Admission controller TLS certificate
- ✅ Cluster admin credentials
- ✅ Database password

---

## 📚 Next Steps

### Add More Databases

```bash
# On Vault server: Store password
vault kv put secret/redisenterprise-redis-enterprise/my-new-db \
  password=MyNewDB123!

# On K8s: Create database
cat <<EOF | kubectl apply -f -
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: my-new-db
  namespace: redis-enterprise
spec:
  name: my-new-db
  memorySize: 100MB
  databasePort: 12001
  databaseSecretName: my-new-db
  tlsMode: enabled
  replication: true
EOF
```

### Add TLS Certificates

Store custom TLS certificates in Vault and reference them in REC spec:

```bash
# On Vault server
vault kv put secret/redisenterprise-redis-enterprise/api-cert \
  tls.crt=@api-cert.pem \
  tls.key=@api-key.pem

# Update REC spec
kubectl patch rec rec -n redis-enterprise --type merge --patch '
spec:
  certificates:
    apiCertificateSecretName: api-cert
'
```

### Configure Backup Credentials

```bash
# On Vault server: Store S3 credentials
vault kv put secret/redisenterprise-redis-enterprise/s3-backup \
  AWS_ACCESS_KEY_ID=<access_key> \
  AWS_SECRET_ACCESS_KEY=<secret_key>

# Update REDB with backup configuration
```

---

## 🔍 Troubleshooting

See [README.md](README.md#troubleshooting) for detailed troubleshooting steps.

### Quick Checks

```bash
# Check Vault connectivity from K8s
kubectl run vault-test --image=curlimages/curl -it --rm -- \
  curl -k https://<VAULT_SERVER_IP>:8200/v1/sys/health

# Check operator logs
kubectl logs -n redis-enterprise \
  -l name=redis-enterprise-operator \
  --tail=100 | grep -i vault

# Check REC status
kubectl describe rec rec -n redis-enterprise

# Check REDB status
kubectl describe redb test-db -n redis-enterprise
```


