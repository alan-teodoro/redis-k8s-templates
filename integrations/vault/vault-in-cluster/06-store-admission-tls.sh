#!/bin/bash
set -e

# ============================================================================
# Store admission-tls in Vault
# ============================================================================
# Este script gera o certificado do admission webhook e armazena no Vault
#
# Pré-requisitos:
# - Redis Enterprise Operator instalado
# - Vault configurado (execute 02-vault-init.sh primeiro)
# - vault-keys.json no diretório atual
#
# Uso:
#   ./06-store-admission-tls.sh
#
# ============================================================================

echo "🔐 Gerando e armazenando admission-tls no Vault..."

# ============================================================================
# 1. Verificar pré-requisitos
# ============================================================================
echo ""
echo "📋 Verificando pré-requisitos..."

if [ ! -f vault-keys.json ]; then
    echo "❌ vault-keys.json não encontrado"
    echo "   Execute 02-vault-init.sh primeiro"
    exit 1
fi

if ! kubectl get deployment redis-enterprise-operator -n redis-enterprise &> /dev/null; then
    echo "❌ Redis Enterprise Operator não encontrado"
    echo "   Instale o operator primeiro"
    exit 1
fi

if ! kubectl get pods -n vault | grep -q vault-0; then
    echo "❌ Vault não encontrado"
    exit 1
fi

echo "✅ Pré-requisitos OK"

# ============================================================================
# 2. Aguardar operator subir
# ============================================================================
echo ""
echo "⏳ Aguardando operator ficar pronto..."

kubectl wait --for=condition=available deployment/redis-enterprise-operator \
  -n redis-enterprise \
  --timeout=120s

sleep 10  # Aguardar um pouco mais para garantir

echo "✅ Operator pronto"

# ============================================================================
# 3. Gerar certificado
# ============================================================================
echo ""
echo "📜 Gerando certificado admission-tls..."

OPERATOR_POD=$(kubectl get pod -l name=redis-enterprise-operator \
  -n redis-enterprise \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$OPERATOR_POD" ]; then
    echo "❌ Pod do operator não encontrado"
    exit 1
fi

echo "   Usando pod: $OPERATOR_POD"

# Gerar certificado
kubectl exec -n redis-enterprise $OPERATOR_POD \
  -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer 2>/dev/null | tail -4 > admission-tls.json

if [ ! -s admission-tls.json ]; then
    echo "❌ Falha ao gerar certificado"
    exit 1
fi

echo "✅ Certificado gerado"

# ============================================================================
# 4. Extrair dados
# ============================================================================
echo ""
echo "🔑 Extraindo dados do certificado..."

CERT=$(cat admission-tls.json | jq -r .cert)
PRIVATE_KEY=$(cat admission-tls.json | jq -r .privateKey)

if [ -z "$CERT" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Falha ao extrair dados do certificado"
    exit 1
fi

echo "✅ Dados extraídos"

# ============================================================================
# 5. Armazenar no Vault
# ============================================================================
echo ""
echo "💾 Armazenando no Vault..."

# Extrair root token
ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')

# Login
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN > /dev/null

# Armazenar secret
kubectl exec -n vault vault-0 -- vault kv put \
  secret/redisenterprise-redis-enterprise/admission-tls \
  cert="$CERT" \
  privateKey="$PRIVATE_KEY" > /dev/null

echo "✅ Secret armazenado no Vault"

# ============================================================================
# 6. Verificar
# ============================================================================
echo ""
echo "🔍 Verificando..."

kubectl exec -n vault vault-0 -- vault kv get \
  secret/redisenterprise-redis-enterprise/admission-tls > /dev/null

echo "✅ Secret verificado"

# ============================================================================
# 7. Reiniciar operator
# ============================================================================
echo ""
echo "🔄 Reiniciando operator..."

kubectl rollout restart deployment/redis-enterprise-operator -n redis-enterprise

echo "⏳ Aguardando operator reiniciar..."

kubectl wait --for=condition=available deployment/redis-enterprise-operator \
  -n redis-enterprise \
  --timeout=120s

echo "✅ Operator reiniciado"

# ============================================================================
# 8. Verificar logs
# ============================================================================
echo ""
echo "📋 Verificando logs do admission..."

sleep 5  # Aguardar um pouco para logs aparecerem

kubectl logs -n redis-enterprise deployment/redis-enterprise-operator \
  -c admission \
  --tail=10 | grep -i "vault\|tls" || true

# ============================================================================
# 9. Resumo
# ============================================================================
echo ""
echo "✅ admission-tls configurado com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "   1. Armazene credenciais do cluster no Vault:"
echo "      kubectl exec -n vault vault-0 -- vault kv put \\"
echo "        secret/redisenterprise-redis-enterprise/rec \\"
echo "        username=demo@redislabs.com \\"
echo "        password='MySecurePassword123!'"
echo ""
echo "   2. Deploy do REC:"
echo "      kubectl apply -f 04-rec-with-vault.yaml"
echo ""
echo "   3. Deploy do Database:"
echo "      kubectl apply -f 05-database-with-vault.yaml"
echo ""

