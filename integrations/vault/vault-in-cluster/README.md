# Vault in Cluster - Redis Enterprise Integration

Deploy completo do HashiCorp Vault dentro do Kubernetes e integração com Redis Enterprise.

## 📋 Visão Geral

Esta implementação instala o Vault diretamente no cluster Kubernetes usando Helm, configurando:
- Vault com HA (3 réplicas) usando Raft storage
- Vault Agent Injector para injeção automática de secrets
- Integração completa com Redis Enterprise Operator
- Tudo via DNS interno do Kubernetes (sem IPs externos)

## 🎯 Vantagens

- ✅ **Setup simples**: Tudo via `kubectl` e `helm`
- ✅ **HA nativo**: StatefulSet com 3 réplicas
- ✅ **Latência mínima**: Rede interna do cluster
- ✅ **Sem Security Groups**: Não precisa configurar firewall
- ✅ **Custo reduzido**: Usa nodes existentes do cluster
- ✅ **Manutenção automatizada**: Kubernetes gerencia tudo

## 📁 Arquivos

```
vault-in-cluster/
├── README.md                          # Este arquivo
├── 01-vault-deployment.yaml           # Deploy do Vault (Helm values)
├── 02-vault-init.sh                   # Script de inicialização
├── 03-operator-config.yaml            # ConfigMap do Operator
├── 04-rec-with-vault.yaml             # REC com Vault
└── 05-database-with-vault.yaml        # Database com Vault
```

## 🚀 Passo a Passo

### Passo 1: Deploy do Vault

```bash
# Adicionar repo do Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Instalar Vault com HA
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.ha.raft.enabled=true" \
  --set "injector.enabled=true" \
  --set "ui.enabled=true"

# Verificar pods
kubectl get pods -n vault
# Esperado: vault-0, vault-1, vault-2 (0/1 Running - sealed)
#           vault-agent-injector-xxx (1/1 Running)
```

### Passo 2: Inicializar e Unseal o Vault

```bash
# Inicializar Vault (apenas no vault-0)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# ⚠️ IMPORTANTE: Salvar vault-keys.json em local seguro!

# Extrair keys
UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Unseal vault-0
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3

# Unseal vault-1 e vault-2
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-1 -- vault operator unseal $UNSEAL_KEY_3

kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-2 -- vault operator unseal $UNSEAL_KEY_3

# Verificar status
kubectl get pods -n vault
# Esperado: vault-0, vault-1, vault-2 (1/1 Running)
```

### Passo 3: Configurar Kubernetes Auth

```bash
# Login no Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

# Habilitar KV v2
kubectl exec -n vault vault-0 -- vault secrets enable -version=2 -path=secret kv

# Habilitar Kubernetes auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configurar Kubernetes auth (usa DNS interno!)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Criar policy para Redis Enterprise
kubectl exec -n vault vault-0 -- vault policy write redisenterprise-redis-enterprise - <<EOF
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF

# Criar roles
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

### Passo 4: Deploy Redis Enterprise Operator

```bash
# Criar namespace
kubectl create namespace redis-enterprise

# Aplicar ConfigMap do Operator
kubectl apply -f 03-operator-config.yaml

# Instalar Operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/redis-enterprise-cluster_rhel_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml

# Aguardar operator (vai ficar 1/2 até próximo passo)
kubectl get pods -n redis-enterprise -w
```

### Passo 5: Gerar e Armazenar admission-tls

```bash
# Aguardar operator subir
sleep 30

# Gerar certificado
OPERATOR_POD=$(kubectl get pod -l name=redis-enterprise-operator -n redis-enterprise -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n redis-enterprise $OPERATOR_POD -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer 2>/dev/null | tail -4 > admission-tls.json

# Armazenar no Vault
CERT=$(cat admission-tls.json | jq -r .cert)
PRIVATE_KEY=$(cat admission-tls.json | jq -r .privateKey)

kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put secret/redisenterprise-redis-enterprise/admission-tls \
  cert="$CERT" \
  privateKey="$PRIVATE_KEY"

# Reiniciar operator
kubectl rollout restart deployment/redis-enterprise-operator -n redis-enterprise

# Verificar (deve ficar 2/2)
kubectl get pods -n redis-enterprise -w
```

### Passo 6: Criar Credenciais do Cluster

```bash
# Armazenar credenciais do cluster no Vault
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN
kubectl exec -n vault vault-0 -- vault kv put secret/redisenterprise-redis-enterprise/rec \
  username=demo@redislabs.com \
  password='MySecurePassword123!'

# Verificar
kubectl exec -n vault vault-0 -- vault kv get secret/redisenterprise-redis-enterprise/rec
```

### Passo 7: Deploy REC e Database

```bash
# Deploy REC
kubectl apply -f 04-rec-with-vault.yaml

# Aguardar REC ficar pronto
kubectl get rec -n redis-enterprise -w
# Esperado: rec   Running

# Deploy Database
kubectl apply -f 05-database-with-vault.yaml

# Verificar
kubectl get redb -n redis-enterprise
# Esperado: my-database   active
```

## 🔍 Verificação

```bash
# 1. Verificar Vault pods
kubectl get pods -n vault
# Esperado: Todos 1/1 Running

# 2. Verificar Operator
kubectl get pods -n redis-enterprise
# Esperado: redis-enterprise-operator-xxx 2/2 Running

# 3. Verificar logs do admission
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -c admission --tail=20
# Esperado: "new Vault token was created", "TLS key successfully retrieved"

# 4. Verificar secrets injetados no REC
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  cat /vault/secrets/rec.json
# Esperado: {"password": "...", "username": "..."}

# 5. Verificar secrets no Vault
kubectl exec -n vault vault-0 -- vault kv list secret/redisenterprise-redis-enterprise/
# Esperado: admission-tls, rec
```

## 🔧 Diferenças vs Vault Externo

| Aspecto | Vault Externo | Vault in Cluster |
|---------|---------------|------------------|
| **VAULT_SERVER_FQDN** | IP público | `vault.vault.svc.cluster.local` |
| **Vault Agent Injector** | Precisa configurar `externalVaultAddr` | Automático |
| **CA Certificate** | Precisa copiar manualmente | Gerenciado pelo K8s |
| **Kubernetes Auth** | Precisa configurar `kubernetes_host` com URL externa | Usa `https://kubernetes.default.svc:443` |
| **Security Groups** | Necessário | Não necessário |
| **Latência** | Rede externa | Rede interna |

## ⚠️ Troubleshooting

### Vault pods ficam 0/1 (Sealed)
**Causa:** Vault não foi unsealed após restart

**Solução:**
```bash
# Unseal cada pod
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3
# Repetir para vault-1 e vault-2
```

### Operator fica 1/2
**Causa:** Secret `admission-tls` não existe no Vault

**Solução:** Executar Passo 5 novamente

### REC pods ficam em Init
**Causa:** Vault Agent não consegue autenticar

**Verificar:**
```bash
kubectl logs -n redis-enterprise rec-0 -c vault-agent-init
# Procurar por "authentication successful"
```

## 📚 Recursos Adicionais

- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide)
- [Vault HA with Raft](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)
- [Redis Enterprise Vault Integration](https://redis.io/blog/kubernetes-secret/)

## 🔒 Segurança

**⚠️ IMPORTANTE:**
- Salve `vault-keys.json` em local seguro (ex: 1Password, AWS Secrets Manager)
- Nunca commite `vault-keys.json` no Git
- Em produção, considere usar auto-unseal com AWS KMS/GCP KMS
- Rotacione o root token após configuração inicial

## 🎯 Próximos Passos

- Configure backup automático com Velero
- Implemente auto-unseal com Cloud KMS
- Configure audit logs do Vault
- Implemente rotação automática de secrets

