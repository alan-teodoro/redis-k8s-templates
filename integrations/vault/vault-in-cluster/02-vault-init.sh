#!/bin/bash
set -e

# ============================================================================
# Vault Initialization Script - In-Cluster
# ============================================================================
# Este script automatiza a inicialização e configuração do Vault
# rodando dentro do Kubernetes
#
# Pré-requisitos:
# - Vault instalado via Helm no namespace 'vault'
# - kubectl configurado
# - jq instalado
#
# Uso:
#   ./02-vault-init.sh
#
# ============================================================================

echo "🚀 Iniciando configuração do Vault in-cluster..."

# ============================================================================
# 1. Verificar pré-requisitos
# ============================================================================
echo ""
echo "📋 Verificando pré-requisitos..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Instale kubectl primeiro."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq não encontrado. Instale jq primeiro."
    exit 1
fi

# Verificar se Vault está rodando
if ! kubectl get pods -n vault | grep -q vault-0; then
    echo "❌ Vault não encontrado no namespace 'vault'"
    echo "   Execute: helm install vault hashicorp/vault ..."
    exit 1
fi

echo "✅ Pré-requisitos OK"

# ============================================================================
# 2. Inicializar Vault
# ============================================================================
echo ""
echo "🔐 Inicializando Vault..."

# Verificar se já foi inicializado
if kubectl exec -n vault vault-0 -- vault status 2>&1 | grep -q "Initialized.*true"; then
    echo "⚠️  Vault já foi inicializado"
    echo "   Se você perdeu as keys, será necessário reinstalar o Vault"
    read -p "   Continuar mesmo assim? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    # Inicializar
    kubectl exec -n vault vault-0 -- vault operator init \
      -key-shares=5 \
      -key-threshold=3 \
      -format=json > vault-keys.json
    
    echo "✅ Vault inicializado"
    echo "⚠️  IMPORTANTE: vault-keys.json foi criado - GUARDE EM LOCAL SEGURO!"
fi

# ============================================================================
# 3. Extrair keys
# ============================================================================
echo ""
echo "🔑 Extraindo unseal keys..."

UNSEAL_KEY_1=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-keys.json | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

echo "✅ Keys extraídas"

# ============================================================================
# 4. Unseal Vault pods
# ============================================================================
echo ""
echo "🔓 Unsealing Vault pods..."

for pod in vault-0 vault-1 vault-2; do
    echo "   Unsealing $pod..."
    kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_1 > /dev/null
    kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_2 > /dev/null
    kubectl exec -n vault $pod -- vault operator unseal $UNSEAL_KEY_3 > /dev/null
done

echo "✅ Todos os pods unsealed"

# ============================================================================
# 5. Aguardar pods ficarem prontos
# ============================================================================
echo ""
echo "⏳ Aguardando pods ficarem prontos..."
kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=60s
echo "✅ Pods prontos"

# ============================================================================
# 6. Configurar Vault
# ============================================================================
echo ""
echo "⚙️  Configurando Vault..."

# Login
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN > /dev/null

# Habilitar KV v2
echo "   Habilitando KV v2..."
kubectl exec -n vault vault-0 -- vault secrets enable -version=2 -path=secret kv 2>/dev/null || echo "   (já habilitado)"

# Habilitar Kubernetes auth
echo "   Habilitando Kubernetes auth..."
kubectl exec -n vault vault-0 -- vault auth enable kubernetes 2>/dev/null || echo "   (já habilitado)"

# Configurar Kubernetes auth
echo "   Configurando Kubernetes auth..."
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" > /dev/null

echo "✅ Vault configurado"

# ============================================================================
# 7. Criar policy e roles para Redis Enterprise
# ============================================================================
echo ""
echo "📜 Criando policy e roles..."

kubectl exec -n vault vault-0 -- vault policy write redisenterprise-redis-enterprise - <<EOF > /dev/null
path "secret/data/redisenterprise-redis-enterprise/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/redisenterprise-redis-enterprise/*" {
  capabilities = ["list"]
}
EOF

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/redis-enterprise-operator-redis-enterprise \
  bound_service_account_names=redis-enterprise-operator \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h > /dev/null

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/redis-enterprise-rec-redis-enterprise \
  bound_service_account_names=rec \
  bound_service_account_namespaces=redis-enterprise \
  policies=redisenterprise-redis-enterprise \
  ttl=1h > /dev/null

echo "✅ Policy e roles criados"

# ============================================================================
# 8. Resumo
# ============================================================================
echo ""
echo "✅ Vault configurado com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "   1. Guarde vault-keys.json em local seguro (1Password, AWS Secrets Manager, etc)"
echo "   2. kubectl apply -f 03-operator-config.yaml"
echo "   3. Instale o Redis Enterprise Operator"
echo "   4. Execute o script de geração do admission-tls"
echo "   5. kubectl apply -f 04-rec-with-vault.yaml"
echo ""
echo "🔑 Root Token: $ROOT_TOKEN"
echo "   (use para acessar a UI do Vault)"
echo ""

