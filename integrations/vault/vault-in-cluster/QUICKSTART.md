# Vault in Cluster - Quick Start

Deploy completo do Vault + Redis Enterprise em 5 minutos.

## 🚀 Passo a Passo Rápido

### 1️⃣ Deploy do Vault

```bash
# Adicionar repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Instalar Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --values 01-vault-helm-values.yaml

# Aguardar pods (ficarão 0/1 - sealed)
kubectl get pods -n vault -w
```

### 2️⃣ Inicializar Vault

```bash
# Executar script de inicialização
./02-vault-init.sh

# ⚠️ IMPORTANTE: Guarde vault-keys.json em local seguro!
```

### 3️⃣ Deploy Redis Enterprise Operator

```bash
# Criar namespace
kubectl create namespace redis-enterprise

# Aplicar ConfigMap
kubectl apply -f 03-operator-config.yaml

# Instalar Operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/redis-enterprise-cluster_rhel_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml

# Aguardar (ficará 1/2 até próximo passo)
kubectl get pods -n redis-enterprise -w
```

### 4️⃣ Gerar e Armazenar admission-tls

```bash
# Executar script
./06-store-admission-tls.sh

# Operator deve ficar 2/2
kubectl get pods -n redis-enterprise
```

### 5️⃣ Armazenar Credenciais do Cluster

```bash
# Extrair root token
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Login
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Armazenar credenciais
kubectl exec -n vault vault-0 -- vault kv put \
  secret/redisenterprise-redis-enterprise/rec \
  username=demo@redislabs.com \
  password='MySecurePassword123!'
```

### 6️⃣ Deploy REC e Database

```bash
# Deploy REC
kubectl apply -f 04-rec-with-vault.yaml

# Aguardar REC ficar pronto
kubectl get rec -n redis-enterprise -w

# Deploy Database
kubectl apply -f 05-database-with-vault.yaml

# Verificar
kubectl get redb -n redis-enterprise
```

## ✅ Verificação

```bash
# 1. Vault pods
kubectl get pods -n vault
# Esperado: vault-0, vault-1, vault-2 (1/1 Running)

# 2. Operator
kubectl get pods -n redis-enterprise
# Esperado: redis-enterprise-operator-xxx (2/2 Running)

# 3. REC
kubectl get rec -n redis-enterprise
# Esperado: rec (Running)

# 4. Database
kubectl get redb -n redis-enterprise
# Esperado: my-database (active)

# 5. Secrets no Vault
kubectl exec -n vault vault-0 -- vault kv list secret/redisenterprise-redis-enterprise/
# Esperado: admission-tls, rec
```

## 🔍 Troubleshooting Rápido

### Vault pods 0/1 (Sealed)
```bash
# Unseal manualmente
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')

kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3
```

### Operator 1/2
```bash
# Verificar logs do admission
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20

# Re-executar script
./06-store-admission-tls.sh
```

### REC pods em Init
```bash
# Verificar Vault Agent
kubectl logs -n redis-enterprise rec-0 -c vault-agent-init

# Verificar se secret existe
kubectl exec -n vault vault-0 -- vault kv get secret/redisenterprise-redis-enterprise/rec
```

## 🎯 Próximos Passos

- Configure backup com Velero
- Implemente auto-unseal com Cloud KMS
- Configure audit logs do Vault
- Rotacione secrets periodicamente

## 📚 Documentação Completa

Veja [README.md](./README.md) para documentação detalhada.

