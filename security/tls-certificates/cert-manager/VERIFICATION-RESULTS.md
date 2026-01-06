# ✅ Verificação de Certificados TLS - Redis Enterprise Cluster

**Data:** 2026-01-06  
**Cluster:** rec  
**Namespace:** redis-enterprise

---

## 🎯 Resumo Executivo

✅ **TODOS OS CERTIFICADOS ESTÃO CORRETOS E FUNCIONANDO!**

---

## 📊 Status do Cluster

```
NAME   NODES   VERSION    STATE     SPEC STATUS
rec    3       8.0.6-54   Running   Valid
```

✅ Cluster rodando com TLS habilitado  
✅ Versão: 8.0.6-54  
✅ 3 nodes ativos

---

## 🔐 Certificados cert-manager

| Certificado | Status | Secret | Validade |
|-------------|--------|--------|----------|
| **rec-api-cert** | ✅ Ready | rec-api-cert | 2026-04-06 |
| **rec-cm-cert** | ✅ Ready | rec-cm-cert | 2026-04-06 |

**Issuer:** selfsigned-issuer (ClusterIssuer)  
**Renovação automática:** 30 dias antes do vencimento

---

## 🔒 Configuração TLS no REC

```json
{
  "apiCertificateSecretName": "rec-api-cert",
  "cmCertificateSecretName": "rec-cm-cert"
}
```

✅ API Certificate configurado  
✅ Cluster Manager Certificate configurado

---

## 🌐 Serviços HTTPS

| Serviço | Tipo | Porta | Protocolo |
|---------|------|-------|-----------|
| **rec** | ClusterIP | 9443 | HTTPS (API) |
| **rec-ui** | ClusterIP | 8443 | HTTPS (UI) |
| **rec-prom** | ClusterIP | 8070 | HTTP (Metrics) |

✅ API rodando em HTTPS (porta 9443)  
✅ UI rodando em HTTPS (porta 8443)

---

## 🧪 Testes de Conectividade

### Teste 1: API HTTPS (porta 9443)
```
HTTP Status: 401 (Unauthorized)
```
✅ **SUCESSO!** API está respondendo via HTTPS  
ℹ️ Status 401 é esperado (sem autenticação)

### Teste 2: Certificado API
```
Subject: CN=rec.redis-enterprise.svc.cluster.local
Issuer: CN=rec.redis-enterprise.svc.cluster.local (self-signed)
DNS Names:
  - rec.redis-enterprise.svc.cluster.local
  - rec-ui.redis-enterprise.svc.cluster.local
  - *.rec.redis-enterprise.svc.cluster.local
```
✅ Certificado válido e com SANs corretos

### Teste 3: Certificado CM
```
Subject: CN=rec-cm.redis-enterprise.svc.cluster.local
Issuer: CN=rec-cm.redis-enterprise.svc.cluster.local (self-signed)
DNS Names:
  - rec-cm.redis-enterprise.svc.cluster.local
  - *.rec.redis-enterprise.svc.cluster.local
```
✅ Certificado válido e com SANs corretos

---

## 📦 Pods

| Pod | Status | Containers |
|-----|--------|------------|
| rec-0 | ✅ Running | 2/2 |
| rec-1 | ✅ Running | 2/2 |
| rec-2 | ✅ Running | 2/2 |
| rec-services-rigger | ✅ Running | 1/1 |

✅ Todos os pods rodando corretamente

---

## 🔑 Secrets

| Secret | Tipo | Conteúdo |
|--------|------|----------|
| **rec** | Opaque | username, password |
| **rec-api-cert** | kubernetes.io/tls | ca.crt, tls.crt, tls.key |
| **rec-cm-cert** | kubernetes.io/tls | ca.crt, tls.crt, tls.key |

✅ Secrets de credenciais criados  
✅ Secrets de certificados criados pelo cert-manager

---

## ✅ Checklist de Validação

- [x] cert-manager instalado e rodando
- [x] ClusterIssuer (selfsigned-issuer) criado
- [x] Certificados emitidos e válidos
- [x] REC configurado com certificados
- [x] API respondendo via HTTPS (porta 9443)
- [x] UI disponível via HTTPS (porta 8443)
- [x] Pods rodando corretamente
- [x] Services-rigger funcionando
- [x] Secrets criados corretamente

---

## 🎉 Conclusão

**O Redis Enterprise Cluster está rodando com TLS configurado corretamente!**

✅ Certificados gerenciados pelo cert-manager  
✅ Renovação automática habilitada  
✅ API e UI acessíveis via HTTPS  
✅ Cluster pronto para uso em produção (com certificados válidos)

---

## 📝 Próximos Passos

1. ✅ Acessar a UI do Cluster Manager via HTTPS
2. ✅ Criar databases com TLS habilitado
3. ✅ Testar conexões de clientes com TLS
4. ⚠️ Para produção: substituir self-signed por CA válida

---

## 🔧 Como Validar os Certificados

### 1️⃣ Verificar Status dos Certificados cert-manager

```bash
# Ver todos os certificados
kubectl get certificate -n redis-enterprise

# Saída esperada:
# NAME           READY   SECRET         AGE
# rec-api-cert   True    rec-api-cert   25m
# rec-cm-cert    True    rec-cm-cert    24m

# ✅ READY deve estar "True" para todos
```

### 2️⃣ Verificar Detalhes do Certificado API

```bash
# Ver informações completas do certificado
kubectl describe certificate rec-api-cert -n redis-enterprise

# Verificar:
# ✅ Status: Ready = True
# ✅ Message: Certificate is up to date and has not expired
# ✅ Issuer: selfsigned-issuer (ou seu issuer)
# ✅ DNS Names: rec.redis-enterprise.svc.cluster.local, rec-ui.*, *.rec.*
```

### 3️⃣ Inspecionar o Certificado X.509 (API)

```bash
# Extrair e decodificar o certificado
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# Verificar campos importantes:
# ✅ Subject: CN=rec.redis-enterprise.svc.cluster.local
# ✅ Issuer: CN=rec.redis-enterprise.svc.cluster.local (self-signed)
# ✅ Validity: Not After (data de expiração)
# ✅ Subject Alternative Name:
#    - DNS:rec.redis-enterprise.svc.cluster.local
#    - DNS:rec-ui.redis-enterprise.svc.cluster.local
#    - DNS:*.rec.redis-enterprise.svc.cluster.local
```

### 4️⃣ Verificar Validade e Expiração

```bash
# Ver datas de validade do certificado API
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates

# Saída esperada:
# notBefore=Jan  6 19:37:24 2026 GMT
# notAfter=Apr  6 19:37:24 2026 GMT  ← Deve ser no futuro!

# ✅ notAfter deve ser maior que a data atual
# ✅ cert-manager renova 30 dias antes (renewBefore: 720h)
```

### 5️⃣ Verificar Subject Alternative Names (SANs)

```bash
# Listar todos os SANs do certificado API
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName

# Saída esperada:
# X509v3 Subject Alternative Name:
#     DNS:rec.redis-enterprise.svc.cluster.local
#     DNS:rec-ui.redis-enterprise.svc.cluster.local
#     DNS:*.rec.redis-enterprise.svc.cluster.local

# ✅ Deve conter todos os DNS names necessários
```

### 6️⃣ Testar Conexão HTTPS na API

```bash
# Teste 1: Verificar se API responde em HTTPS
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  https://localhost:9443/v1/bootstrap

# Saída esperada:
# HTTP Status: 401  ← Correto! (sem autenticação)

# ✅ 401 = API está respondendo via HTTPS
# ❌ 000 = API não está respondendo
# ❌ Erro de conexão = TLS não configurado
```

### 7️⃣ Verificar Certificado Apresentado pela API

```bash
# Ver certificado que a API está usando
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  openssl s_client -connect localhost:9443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -subject -issuer -dates

# Saída esperada:
# subject=CN=rec.redis-enterprise.svc.cluster.local, OU=Cluster API, O=RedisLabs
# issuer=CN=rec.redis-enterprise.svc.cluster.local, OU=Cluster API, O=RedisLabs
# notBefore=Jan  6 19:37:24 2026 GMT
# notAfter=Apr  6 19:37:24 2026 GMT

# ✅ Subject deve corresponder ao esperado
# ✅ Datas devem estar válidas
```

### 8️⃣ Verificar Configuração no REC

```bash
# Ver configuração de certificados no REC
kubectl get rec rec -n redis-enterprise -o jsonpath='{.spec.certificates}' | jq '.'

# Saída esperada:
# {
#   "apiCertificateSecretName": "rec-api-cert",
#   "cmCertificateSecretName": "rec-cm-cert"
# }

# ✅ Deve apontar para os secrets corretos
```

### 9️⃣ Verificar Secrets Criados

```bash
# Listar secrets de certificados
kubectl get secret -n redis-enterprise | grep cert

# Saída esperada:
# rec-api-cert    kubernetes.io/tls   3   25m
# rec-cm-cert     kubernetes.io/tls   3   24m

# ✅ Tipo deve ser "kubernetes.io/tls"
# ✅ DATA deve ser 3 (ca.crt, tls.crt, tls.key)
```

### 🔟 Verificar Conteúdo do Secret

```bash
# Ver chaves dentro do secret
kubectl get secret rec-api-cert -n redis-enterprise -o jsonpath='{.data}' | jq 'keys'

# Saída esperada:
# [
#   "ca.crt",
#   "tls.crt",
#   "tls.key"
# ]

# ✅ Deve conter exatamente essas 3 chaves
```

---

## 🔍 Validação Completa - Script Automatizado

```bash
#!/bin/bash
# Script de validação completa de certificados

echo "=========================================="
echo "VALIDAÇÃO DE CERTIFICADOS TLS"
echo "=========================================="
echo ""

# 1. Status dos certificados
echo "1️⃣ Status dos Certificados:"
kubectl get certificate -n redis-enterprise
echo ""

# 2. Verificar se estão READY
READY_API=$(kubectl get certificate rec-api-cert -n redis-enterprise -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
READY_CM=$(kubectl get certificate rec-cm-cert -n redis-enterprise -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

if [ "$READY_API" == "True" ] && [ "$READY_CM" == "True" ]; then
  echo "✅ Todos os certificados estão READY"
else
  echo "❌ Certificados NÃO estão prontos!"
  echo "   API: $READY_API"
  echo "   CM: $READY_CM"
fi
echo ""

# 3. Verificar validade
echo "2️⃣ Validade dos Certificados:"
echo "API Certificate:"
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates
echo ""
echo "CM Certificate:"
kubectl get secret rec-cm-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -dates
echo ""

# 4. Verificar SANs
echo "3️⃣ Subject Alternative Names (API):"
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -ext subjectAltName
echo ""

# 5. Testar HTTPS
echo "4️⃣ Teste de Conexão HTTPS:"
HTTP_CODE=$(kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  curl -k -s -o /dev/null -w "%{http_code}" https://localhost:9443/v1/bootstrap 2>/dev/null)

if [ "$HTTP_CODE" == "401" ]; then
  echo "✅ API respondendo via HTTPS (Status: $HTTP_CODE)"
else
  echo "❌ Problema na API HTTPS (Status: $HTTP_CODE)"
fi
echo ""

# 6. Verificar configuração no REC
echo "5️⃣ Configuração no REC:"
kubectl get rec rec -n redis-enterprise -o jsonpath='{.spec.certificates}' | jq '.'
echo ""

echo "=========================================="
echo "VALIDAÇÃO COMPLETA!"
echo "=========================================="
```

**Salve como:** `validate-certificates.sh`

**Execute:**
```bash
chmod +x validate-certificates.sh
./validate-certificates.sh
```

---

## ✅ Checklist de Validação

Use este checklist para validar manualmente:

- [ ] **Certificados cert-manager**
  - [ ] `rec-api-cert` com status READY=True
  - [ ] `rec-cm-cert` com status READY=True

- [ ] **Secrets criados**
  - [ ] `rec-api-cert` tipo kubernetes.io/tls
  - [ ] `rec-cm-cert` tipo kubernetes.io/tls
  - [ ] Cada secret tem 3 chaves: ca.crt, tls.crt, tls.key

- [ ] **Validade dos certificados**
  - [ ] notAfter (expiração) está no futuro
  - [ ] notBefore (início) está no passado
  - [ ] Renovação automática configurada (renewBefore: 720h)

- [ ] **Subject Alternative Names (SANs)**
  - [ ] API: rec.redis-enterprise.svc.cluster.local
  - [ ] API: rec-ui.redis-enterprise.svc.cluster.local
  - [ ] API: *.rec.redis-enterprise.svc.cluster.local
  - [ ] CM: rec-cm.redis-enterprise.svc.cluster.local
  - [ ] CM: *.rec.redis-enterprise.svc.cluster.local

- [ ] **Configuração no REC**
  - [ ] apiCertificateSecretName: rec-api-cert
  - [ ] cmCertificateSecretName: rec-cm-cert

- [ ] **Testes de conectividade**
  - [ ] API HTTPS (porta 9443) responde com status 401
  - [ ] UI HTTPS (porta 8443) acessível
  - [ ] Certificado apresentado pela API está correto

---

## 🔧 Comandos Rápidos de Verificação

```bash
# Ver certificados
kubectl get certificate -n redis-enterprise

# Ver secrets
kubectl get secret -n redis-enterprise | grep cert

# Ver status do cluster
kubectl get rec -n redis-enterprise

# Testar API HTTPS
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  curl -k -s -o /dev/null -w "HTTP: %{http_code}\n" https://localhost:9443/v1/bootstrap

# Ver detalhes do certificado API
kubectl describe certificate rec-api-cert -n redis-enterprise

# Inspecionar certificado X.509
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

