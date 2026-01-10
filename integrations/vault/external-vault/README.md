# HashiCorp Vault Integration with Redis Enterprise

Integration of Redis Enterprise Operator with HashiCorp Vault for centralized secrets management.

## ⚠️ CRITICAL REQUIREMENTS

**Redis Enterprise Operator REQUIRES HTTPS for Vault integration.**

- ❌ HTTP is not supported
- ✅ HTTPS is mandatory (port 8200)
- ✅ Self-signed certificate is accepted
- ✅ KV v2 secrets engine is mandatory
- ✅ **Vault VM MUST have network access to Kubernetes API** (port 443)
- ✅ **Kubernetes MUST have network access to Vault** (port 8200)

## 📁 Files

- **`01-operator-config.yaml`** - Operator ConfigMap with Vault variables
- **`02-rec-with-vault.yaml`** - Redis Enterprise Cluster using Vault
- **`03-database-with-vault.yaml`** - Redis Database using Vault

## 📋 Network Prerequisites (AWS)

### ⚠️ CRITICAL: Security Groups

**The integration will NOT work without these network configurations!**

#### 1. EKS Security Group
```bash
# Allow Vault VM to access Kubernetes API
aws ec2 authorize-security-group-ingress \
  --group-id <EKS_CLUSTER_SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 443 \
  --cidr <VAULT_VM_PRIVATE_IP>/32
```

**How to get the Security Group ID:**
```bash
aws eks describe-cluster --name <CLUSTER_NAME> \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text
```

#### 2. Vault VM Security Group
- **Outbound:** Must allow all traffic (default) or at least port 443 to EKS

#### 3. Connectivity Tests (MANDATORY)

**Test 1: Vault → Kubernetes API**
```bash
# SSH to Vault VM
ssh -i <key.pem> ubuntu@<VAULT_PUBLIC_IP>

# Get private IP of K8s API
nslookup <EKS_API_ENDPOINT>
# Example: 694BFB09A17CDA85A62DB07C6508A656.gr7.us-east-1.eks.amazonaws.com
# Result: 172.31.14.21, 172.31.73.148

# Test connectivity
curl -k -m 5 https://172.31.14.21:443/version
```
**✅ Expected:** JSON with Kubernetes version
**❌ If timeout:** EKS Security Group does not allow access from VM

**Test 2: Kubernetes → Vault**
```bash
kubectl run test --rm -it --image=curlimages/curl -- \
  curl -k https://<VAULT_PUBLIC_IP>:8200/v1/sys/health
```
**✅ Expected:** JSON with Vault status
**❌ If timeout:** VM Security Group does not allow access from K8s

## 🚀 Complete Setup

### Step 1: Configure Vault with HTTPS

**⚠️ Run these commands ON THE VAULT VM via SSH:**

```bash
# SSH to Vault VM
ssh -i <key.pem> ubuntu@<VAULT_IP>

# Create directory for TLS
sudo mkdir -p /opt/vault/tls
cd /opt/vault/tls

# Generate self-signed certificate
sudo openssl genrsa -out vault-key.pem 2048
sudo openssl req -new -x509 -key vault-key.pem -out vault-cert.pem -days 365 \
  -subj "/C=US/ST=NY/L=NYC/O=Redis/CN=<VAULT_IP>"

# Configure permissions
sudo chmod 600 vault-key.pem
sudo chmod 644 vault-cert.pem
sudo chown -R vault:vault /opt/vault/tls

# Configure Vault for HTTPS
sudo tee /etc/vault.d/vault.hcl > /dev/null <<EOF
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault-cert.pem"
  tls_key_file  = "/opt/vault/tls/vault-key.pem"
}

api_addr = "https://<VAULT_IP>:8200"
cluster_addr = "https://<VAULT_IP>:8201"
ui = true
EOF

# Reiniciar Vault
sudo systemctl restart vault
sudo systemctl status vault

# Testar HTTPS
curl -k https://127.0.0.1:8200/v1/sys/health

# Se Vault não estiver inicializado, inicializar e fazer unseal
vault operator init -key-shares=1 -key-threshold=1
# IMPORTANTE: Salvar o Unseal Key e Root Token!

vault operator unseal <UNSEAL_KEY>
vault login <ROOT_TOKEN>
```

### 2. Criar Secret com CA Certificate no K8s

**⚠️ Execute estes comandos NO SEU TERMINAL LOCAL:**

```bash
# Criar namespace redis-enterprise
kubectl create namespace redis-enterprise

# Copiar CA do Vault
scp -i <key.pem> ubuntu@<VAULT_IP>:/opt/vault/tls/vault-cert.pem ./vault-ca.pem

# Criar secret no K8s
kubectl create secret generic vault-ca-cert \
  --namespace redis-enterprise \
  --from-file=vault.ca=./vault-ca.pem

# Verificar
kubectl get secret vault-ca-cert -n redis-enterprise
```

### 3. Configurar Vault (Kubernetes Auth + Policy + Roles)

#### 3.1. Preparar Kubernetes (NO SEU TERMINAL LOCAL)

```bash
# Criar namespace vault
kubectl create namespace vault

# Criar ServiceAccount para autenticação
kubectl create serviceaccount vault-auth -n vault

# Criar secret para o ServiceAccount (K8s 1.24+)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: vault
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
EOF

# Criar ClusterRoleBinding
kubectl create clusterrolebinding vault-tokenreview-binding \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault:vault-auth

# Obter informações do K8s para configurar no Vault
K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')
K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)
SA_JWT_TOKEN=$(kubectl get secret vault-auth-token -n vault -o jsonpath='{.data.token}' | base64 -d)

# Exibir valores (você vai precisar copiar para a VM do Vault)
echo "K8S_HOST: $K8S_HOST"
echo ""
echo "K8S_CA_CERT:"
echo "$K8S_CA_CERT"
echo ""
echo "SA_JWT_TOKEN:"
echo "$SA_JWT_TOKEN"
```

#### 3.2. Configurar Vault (NA VM DO VAULT)

**⚠️ SSH na VM do Vault e execute:**

```bash
# SSH na VM do Vault
ssh -i <key.pem> ubuntu@<VAULT_IP>

# Configurar variáveis de ambiente
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_SKIP_VERIFY=true
vault login <ROOT_TOKEN>

# Habilitar KV v2
vault secrets enable -version=2 -path=secret kv

# Configurar variáveis obtidas do K8s (copiar do passo anterior)
export K8S_HOST="<VALOR_DO_PASSO_ANTERIOR>"
export SA_JWT_TOKEN="<VALOR_DO_PASSO_ANTERIOR>"
export K8S_CA_CERT="<VALOR_DO_PASSO_ANTERIOR>"

# Habilitar Kubernetes auth
vault auth enable kubernetes

# Configurar Kubernetes auth
vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$K8S_CA_CERT"

# Criar policy para Redis Enterprise
vault policy write redisenterprise-redis-enterprise - <<EOF
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF

# Criar role para o Operator
vault write auth/kubernetes/role/redis-enterprise-operator-redis-enterprise \
  bound_service_account_names=redis-enterprise-operator \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h

# Criar role para o REC (cluster)
vault write auth/kubernetes/role/redis-enterprise-rec-redis-enterprise \
  bound_service_account_names=rec \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h

# Verificar configuração
vault read auth/kubernetes/config
vault policy read redisenterprise-redis-enterprise
vault read auth/kubernetes/role/redis-enterprise-operator-redis-enterprise
```

### 4. Instalar Vault Agent Injector

**⚠️ Execute estes comandos NO SEU TERMINAL LOCAL:**

```bash
# Adicionar repo do Vault Helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Instalar Vault Agent Injector (IMPORTANTE: usar HTTPS)
helm install vault hashicorp/vault \
  --namespace vault \
  --set "injector.enabled=true" \
  --set "injector.externalVaultAddr=https://<VAULT_IP>:8200" \
  --set "server.enabled=false"

# Verificar instalação
kubectl get pods -n vault
# Esperado: vault-agent-injector-xxx 1/1 Running
```

### 5. Aplicar Configuração do Operator

**⚠️ Execute estes comandos NO SEU TERMINAL LOCAL:**

```bash
# Editar 01-operator-config.yaml
# Alterar VAULT_SERVER_FQDN para o IP do seu Vault
# Exemplo: VAULT_SERVER_FQDN: "44.203.198.21"

# Aplicar ConfigMap
kubectl apply -f 01-operator-config.yaml

# Verificar ConfigMap
kubectl get configmap operator-environment-config -n redis-enterprise -o yaml

# Instalar operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/redis-enterprise-cluster_rhel_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml

# Aguardar operator subir (vai ficar 1/2 até o passo 6)
kubectl get pods -n redis-enterprise -w
```

### 6. Gerar e Armazenar admission-tls no Vault

**⚠️ IMPORTANTE: O operator vai ficar 1/2 até este passo ser concluído!**

#### 6.1. Gerar certificado TLS (NO SEU TERMINAL LOCAL)

```bash
# Aguardar operator subir (vai ficar 1/2)
sleep 30

# Obter nome do pod do operator
OPERATOR_POD=$(kubectl get pod -l name=redis-enterprise-operator -n redis-enterprise -o jsonpath='{.items[0].metadata.name}')

# Gerar TLS certificate
kubectl exec -n redis-enterprise $OPERATOR_POD -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer 2>/dev/null | tail -4 > admission-tls.json

# Verificar conteúdo do arquivo
cat admission-tls.json
```

**Exemplo do conteúdo esperado:**
```json
{
  "cert": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...",
  "privateKey": "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt..."
}
```

#### 6.2. Armazenar no Vault (NA VM DO VAULT)

```bash
# SSH na VM do Vault
ssh -i <key.pem> ubuntu@<VAULT_IP>

# Configurar Vault
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_SKIP_VERIFY=true
vault login <ROOT_TOKEN>

# Copiar os valores de cert e privateKey do arquivo admission-tls.json
# e executar o comando abaixo substituindo os valores

vault kv put secret/redisenterprise-redis-enterprise/admission-tls \
  cert='LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...' \
  privateKey='LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt...'

# Verificar se foi armazenado
vault kv get secret/redisenterprise-redis-enterprise/admission-tls
```

#### 6.3. Reiniciar Operator (NO SEU TERMINAL LOCAL)

```bash
# Reiniciar operator
kubectl rollout restart deployment/redis-enterprise-operator -n redis-enterprise

# Aguardar e verificar se subiu 2/2
kubectl get pods -n redis-enterprise -w
```

**✅ Esperado:** Operator deve ficar 2/2 Running

**Verificar logs:**
```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20
# Esperado: "new Vault token was created", "TLS key successfully retrieved"
```

### 7. Criar Credenciais do Cluster no Vault

**⚠️ Execute estes comandos NA VM DO VAULT:**

```bash
# SSH na VM do Vault (se não estiver conectado)
ssh -i <key.pem> ubuntu@<VAULT_IP>

# Configurar Vault
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_SKIP_VERIFY=true
vault login <ROOT_TOKEN>

# Criar credenciais do cluster
vault kv put secret/redisenterprise-redis-enterprise/rec \
  username=demo@redislabs.com \
  password='MySecurePassword123!'

# Verificar
vault kv get secret/redisenterprise-redis-enterprise/rec
```

### 8. Criar REC e Database

**⚠️ Execute estes comandos NO SEU TERMINAL LOCAL:**

```bash
# Aplicar manifests
kubectl apply -f 02-rec-with-vault.yaml

# Aguardar REC ficar pronto (pode levar alguns minutos)
kubectl get rec -n redis-enterprise -w
# Esperado: rec   Running

# Verificar pods do REC
kubectl get pods -n redis-enterprise
# Esperado: rec-0, rec-1, rec-2 todos 2/2 Running

# Criar database
kubectl apply -f 03-database-with-vault.yaml

# Verificar database
kubectl get redb -n redis-enterprise
# Esperado: my-database   active
```

## 🔍 Verificação

```bash
# 1. Operator deve estar 2/2
kubectl get pods -n redis-enterprise
# Esperado: redis-enterprise-operator-xxx 2/2 Running

# 2. Verificar logs do admission (deve mostrar autenticação bem-sucedida)
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20
# Esperado: "new Vault token was created", "TLS key successfully retrieved"

# 3. Verificar secrets injetados no REC pod
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  cat /vault/secrets/rec.json
# Esperado: {"password": "...", "username": "..."}

# 4. Verificar secrets no Vault
vault kv list secret/redisenterprise-redis-enterprise/
# Esperado: admission-tls, rec
```

## ⚠️ Troubleshooting

Consulte o arquivo **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** para problemas detalhados e soluções.

### Problemas Comuns

#### 1. Operator fica 1/2 Running
**Causas:**
- ❌ Vault não está em HTTPS
- ❌ Secret `vault-ca-cert` não existe no namespace
- ❌ Secret `admission-tls` não existe no Vault
- ❌ Security Group do EKS não permite acesso da VM do Vault

**Verificar:**
```bash
# Logs do admission
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=50

# Procurar por:
# - "Vault create token: 403" → Problema de rede/autenticação
# - "failed to retrieve TLS key" → Secret admission-tls não existe
```

#### 2. REC Pods ficam em Init (Vault Agent Timeout)
**Causas:**
- ❌ Vault Agent Injector configurado com HTTP em vez de HTTPS
- ❌ Vault Agent Injector com IP errado

**Verificar:**
```bash
# Verificar configuração do Vault Agent Injector
kubectl get deployment -n vault vault-agent-injector -o yaml | grep AGENT_INJECT_VAULT_ADDR
# Esperado: https://<VAULT_PUBLIC_IP>:8200

# Logs do vault-agent-init
kubectl logs -n redis-enterprise rec-0 -c vault-agent-init --tail=30
# Procurar por: "authentication successful"
```

**Corrigir:**
```bash
kubectl set env deployment/vault-agent-injector -n vault \
  AGENT_INJECT_VAULT_ADDR=https://<VAULT_PUBLIC_IP>:8200
```

#### 3. REC Pod com "FailedScheduling" (Insufficient CPU)
**Causa:**
- ❌ Cluster EKS sem recursos suficientes

**Solução:**
```bash
# Opção A: Escalar node group
aws eks update-nodegroup-config \
  --cluster-name <CLUSTER_NAME> \
  --nodegroup-name <NODEGROUP_NAME> \
  --scaling-config minSize=4,maxSize=6,desiredSize=4

# Opção B: Reduzir resource requests no 02-rec-with-vault.yaml
```

## 📚 Documentação

- [Redis Enterprise Vault Integration](https://redis.io/blog/kubernetes-secret/)
- [Vault Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

