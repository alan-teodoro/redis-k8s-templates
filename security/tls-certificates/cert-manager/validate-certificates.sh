#!/bin/bash
# Script de Validação de Certificados TLS - Redis Enterprise Cluster
# Valida se os certificados estão configurados corretamente

set -e

NAMESPACE="redis-enterprise"
REC_NAME="rec"

echo "=========================================="
echo "VALIDAÇÃO DE CERTIFICADOS TLS"
echo "Redis Enterprise Cluster: $REC_NAME"
echo "Namespace: $NAMESPACE"
echo "=========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para verificar sucesso
check_success() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $1${NC}"
  else
    echo -e "${RED}❌ $1${NC}"
    exit 1
  fi
}

# Função para verificar warning
check_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Verificar se namespace existe
echo "1️⃣ Verificando namespace..."
kubectl get namespace $NAMESPACE > /dev/null 2>&1
check_success "Namespace $NAMESPACE existe"
echo ""

# 2. Verificar se REC existe
echo "2️⃣ Verificando Redis Enterprise Cluster..."
kubectl get rec $REC_NAME -n $NAMESPACE > /dev/null 2>&1
check_success "REC $REC_NAME existe"

REC_STATE=$(kubectl get rec $REC_NAME -n $NAMESPACE -o jsonpath='{.status.state}')
if [ "$REC_STATE" == "Running" ]; then
  echo -e "${GREEN}✅ REC está Running${NC}"
else
  echo -e "${YELLOW}⚠️  REC está em estado: $REC_STATE${NC}"
fi
echo ""

# 3. Verificar certificados cert-manager
echo "3️⃣ Verificando certificados cert-manager..."
kubectl get certificate -n $NAMESPACE > /dev/null 2>&1
check_success "Certificados encontrados"

echo ""
echo "Certificados disponíveis:"
kubectl get certificate -n $NAMESPACE
echo ""

# 4. Verificar status READY dos certificados
echo "4️⃣ Verificando status READY..."

READY_API=$(kubectl get certificate rec-api-cert -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
READY_CM=$(kubectl get certificate rec-cm-cert -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")

if [ "$READY_API" == "True" ]; then
  echo -e "${GREEN}✅ rec-api-cert está READY${NC}"
else
  echo -e "${RED}❌ rec-api-cert NÃO está READY (Status: $READY_API)${NC}"
fi

if [ "$READY_CM" == "True" ]; then
  echo -e "${GREEN}✅ rec-cm-cert está READY${NC}"
else
  echo -e "${RED}❌ rec-cm-cert NÃO está READY (Status: $READY_CM)${NC}"
fi
echo ""

# 5. Verificar secrets
echo "5️⃣ Verificando secrets de certificados..."

kubectl get secret rec-api-cert -n $NAMESPACE > /dev/null 2>&1
check_success "Secret rec-api-cert existe"

kubectl get secret rec-cm-cert -n $NAMESPACE > /dev/null 2>&1
check_success "Secret rec-cm-cert existe"

echo ""
echo "Secrets de certificados:"
kubectl get secret -n $NAMESPACE | grep -E "NAME|cert"
echo ""

# 6. Verificar conteúdo dos secrets
echo "6️⃣ Verificando conteúdo dos secrets..."

API_KEYS=$(kubectl get secret rec-api-cert -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys | length')
if [ "$API_KEYS" == "3" ]; then
  echo -e "${GREEN}✅ rec-api-cert tem 3 chaves (ca.crt, tls.crt, tls.key)${NC}"
else
  echo -e "${RED}❌ rec-api-cert tem $API_KEYS chaves (esperado: 3)${NC}"
fi

CM_KEYS=$(kubectl get secret rec-cm-cert -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys | length')
if [ "$CM_KEYS" == "3" ]; then
  echo -e "${GREEN}✅ rec-cm-cert tem 3 chaves (ca.crt, tls.crt, tls.key)${NC}"
else
  echo -e "${RED}❌ rec-cm-cert tem $CM_KEYS chaves (esperado: 3)${NC}"
fi
echo ""

# 7. Verificar validade dos certificados
echo "7️⃣ Verificando validade dos certificados..."

echo "API Certificate:"
kubectl get secret rec-api-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates

NOT_AFTER_API=$(kubectl get secret rec-api-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -enddate | cut -d= -f2)
echo -e "${GREEN}✅ Expira em: $NOT_AFTER_API${NC}"
echo ""

echo "CM Certificate:"
kubectl get secret rec-cm-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates

NOT_AFTER_CM=$(kubectl get secret rec-cm-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -enddate | cut -d= -f2)
echo -e "${GREEN}✅ Expira em: $NOT_AFTER_CM${NC}"
echo ""

# 8. Verificar Subject Alternative Names (SANs)
echo "8️⃣ Verificando Subject Alternative Names..."

echo "API Certificate SANs:"
kubectl get secret rec-api-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName

# Verificar se contém os SANs esperados
SANS_API=$(kubectl get secret rec-api-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -c "rec.redis-enterprise.svc.cluster.local" || echo "0")

if [ "$SANS_API" -gt 0 ]; then
  echo -e "${GREEN}✅ SANs corretos no certificado API${NC}"
else
  echo -e "${RED}❌ SANs incorretos no certificado API${NC}"
fi
echo ""

echo "CM Certificate SANs:"
kubectl get secret rec-cm-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName

SANS_CM=$(kubectl get secret rec-cm-cert -n $NAMESPACE \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -c "rec-cm.redis-enterprise.svc.cluster.local" || echo "0")

if [ "$SANS_CM" -gt 0 ]; then
  echo -e "${GREEN}✅ SANs corretos no certificado CM${NC}"
else
  echo -e "${RED}❌ SANs incorretos no certificado CM${NC}"
fi
echo ""

# 9. Verificar configuração no REC
echo "9️⃣ Verificando configuração de certificados no REC..."

API_CERT_NAME=$(kubectl get rec $REC_NAME -n $NAMESPACE -o jsonpath='{.spec.certificates.apiCertificateSecretName}')
CM_CERT_NAME=$(kubectl get rec $REC_NAME -n $NAMESPACE -o jsonpath='{.spec.certificates.cmCertificateSecretName}')

if [ "$API_CERT_NAME" == "rec-api-cert" ]; then
  echo -e "${GREEN}✅ apiCertificateSecretName: $API_CERT_NAME${NC}"
else
  echo -e "${RED}❌ apiCertificateSecretName incorreto: $API_CERT_NAME (esperado: rec-api-cert)${NC}"
fi

if [ "$CM_CERT_NAME" == "rec-cm-cert" ]; then
  echo -e "${GREEN}✅ cmCertificateSecretName: $CM_CERT_NAME${NC}"
else
  echo -e "${RED}❌ cmCertificateSecretName incorreto: $CM_CERT_NAME (esperado: rec-cm-cert)${NC}"
fi
echo ""

# 10. Testar conectividade HTTPS
echo "🔟 Testando conectividade HTTPS..."

# Verificar se pod rec-0 existe
kubectl get pod rec-0 -n $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
  check_warning "Pod rec-0 não encontrado, pulando teste de conectividade"
else
  HTTP_CODE=$(kubectl exec -n $NAMESPACE rec-0 -c redis-enterprise-node -- \
    curl -k -s -o /dev/null -w "%{http_code}" https://localhost:9443/v1/bootstrap 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" == "401" ]; then
    echo -e "${GREEN}✅ API respondendo via HTTPS (Status: $HTTP_CODE)${NC}"
    echo "   (401 é esperado - sem autenticação)"
  elif [ "$HTTP_CODE" == "000" ]; then
    echo -e "${RED}❌ API não está respondendo (Status: $HTTP_CODE)${NC}"
  else
    echo -e "${YELLOW}⚠️  API respondeu com status inesperado: $HTTP_CODE${NC}"
  fi
fi
echo ""

# 11. Verificar serviços
echo "1️⃣1️⃣ Verificando serviços HTTPS..."

echo "Serviços disponíveis:"
kubectl get svc -n $NAMESPACE | grep rec

REC_SVC=$(kubectl get svc rec -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="api")].port}' 2>/dev/null || echo "")
if [ "$REC_SVC" == "9443" ]; then
  echo -e "${GREEN}✅ Serviço 'rec' expondo porta 9443 (HTTPS)${NC}"
else
  echo -e "${YELLOW}⚠️  Serviço 'rec' porta: $REC_SVC${NC}"
fi

REC_UI_SVC=$(kubectl get svc rec-ui -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
if [ "$REC_UI_SVC" == "8443" ]; then
  echo -e "${GREEN}✅ Serviço 'rec-ui' expondo porta 8443 (HTTPS)${NC}"
else
  echo -e "${YELLOW}⚠️  Serviço 'rec-ui' porta: $REC_UI_SVC${NC}"
fi
echo ""

# 12. Resumo final
echo "=========================================="
echo "RESUMO DA VALIDAÇÃO"
echo "=========================================="
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0

# Contar verificações
if [ "$REC_STATE" == "Running" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$READY_API" == "True" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$READY_CM" == "True" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$API_KEYS" == "3" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$CM_KEYS" == "3" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$SANS_API" -gt 0 ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$SANS_CM" -gt 0 ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$API_CERT_NAME" == "rec-api-cert" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$CM_CERT_NAME" == "rec-cm-cert" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

if [ "$HTTP_CODE" == "401" ]; then ((PASSED_CHECKS++)); fi
((TOTAL_CHECKS++))

echo "Verificações passadas: $PASSED_CHECKS/$TOTAL_CHECKS"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
  echo -e "${GREEN}✅ TODOS OS CERTIFICADOS ESTÃO CORRETOS E FUNCIONANDO!${NC}"
  echo ""
  echo "Próximos passos:"
  echo "  1. Acessar UI: kubectl port-forward -n $NAMESPACE svc/rec-ui 8443:8443"
  echo "  2. Criar database com TLS"
  echo "  3. Testar conexão de cliente com TLS"
  exit 0
else
  echo -e "${RED}❌ ALGUMAS VERIFICAÇÕES FALHARAM!${NC}"
  echo ""
  echo "Revise os erros acima e corrija antes de prosseguir."
  exit 1
fi

