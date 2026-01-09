# Troubleshooting - Vault Integration

Este documento descreve os problemas encontrados durante a integração do Redis Enterprise com HashiCorp Vault e suas soluções.

## 🔍 Problemas Encontrados e Soluções

### 1. ❌ Operator Admission Container com Erro 403

**Sintoma:**
```
{"level":"info","ts":"2026-01-09T20:02:10.698Z","logger":"vault_utils","msg":"Vault create token: 403"}
{"level":"error","ts":"2026-01-09T20:02:10.713Z","msg":"GenerateTLS failed to retrieve TLS key"}
```

**Causa Raiz:**
O Vault VM não conseguia acessar o Kubernetes API endpoint para validar os tokens JWT.

**Diagnóstico:**
```bash
# Da VM do Vault, testar conectividade com K8s API
# Primeiro, obter o IP privado do K8s API endpoint
nslookup <EKS_API_ENDPOINT>
# Exemplo: 694BFB09A17CDA85A62DB07C6508A656.gr7.us-east-1.eks.amazonaws.com
# Resultado: 172.31.14.21, 172.31.73.148

# Testar conectividade
ssh -i <key.pem> ubuntu@<VAULT_IP> \
  "curl -k -m 5 https://<K8S_API_PRIVATE_IP>:443/version"
# Resultado esperado se houver problema: Connection timeout
```

**Solução:**
Adicionar regra no Security Group do EKS para permitir acesso da VM do Vault:

```bash
# Obter Security Group ID do EKS
aws eks describe-cluster --name <CLUSTER_NAME> \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text

# Obter IP privado da VM do Vault
aws ec2 describe-instances --instance-ids <VAULT_INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text

# Adicionar regra
aws ec2 authorize-security-group-ingress \
  --group-id <EKS_SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 443 \
  --cidr <VAULT_PRIVATE_IP>/32
```

**Verificação:**
```bash
# Após adicionar a regra
ssh -i <key.pem> ubuntu@<VAULT_IP> \
  "curl -k -m 5 https://<K8S_API_PRIVATE_IP>:443/version"
# Resultado esperado: {"major": "1", "minor": "31", ...}
```

---

### 2. ❌ Vault Agent Init com Timeout HTTP

**Sintoma:**
```
[ERROR] agent.auth.handler: error authenticating: error="Put \"http://<VAULT_IP>:8200/v1/auth/kubernetes/login\": dial tcp <VAULT_IP>:8200: i/o timeout"
```

**Causa Raiz:**
O Vault Agent Injector estava configurado com URL HTTP em vez de HTTPS.

**Diagnóstico:**
```bash
kubectl get deployment -n vault vault-agent-injector -o yaml | grep AGENT_INJECT_VAULT_ADDR
# Resultado incorreto: value: http://<VAULT_IP>:8200
# Resultado correto: value: https://<VAULT_IP>:8200
```

**Solução:**
Atualizar a variável de ambiente do Vault Agent Injector:

```bash
kubectl set env deployment/vault-agent-injector -n vault \
  AGENT_INJECT_VAULT_ADDR=https://<VAULT_IP>:8200
```

**Verificação:**
```bash
kubectl logs -n redis-enterprise rec-1 -c vault-agent-init --tail=5
# Resultado: "authentication successful, sending token to sinks"
```

---

### 3. ❌ Secret `admission-tls` Não Existia no Vault

**Sintoma:**
Operator não conseguia iniciar o container de admission.

**Causa Raiz:**
O secret `admission-tls` precisa ser criado manualmente no Vault antes de iniciar o operator.

**Solução:**
```bash
# 1. Gerar o certificado TLS
kubectl exec -n redis-enterprise <operator-pod> -c redis-enterprise-operator -- \
  /usr/local/bin/generate-tls -infer > admission-tls.json

# 2. Armazenar no Vault
vault kv put secret/redisenterprise-redis-enterprise/admission-tls \
  cert="$(cat admission-tls.json | jq -r .cert)" \
  privateKey="$(cat admission-tls.json | jq -r .privateKey)"
```

---

## ✅ Checklist de Pré-requisitos

Antes de iniciar a integração, verifique:

- [ ] **Vault está rodando com HTTPS** (porta 8200)
- [ ] **KV v2 secret engine habilitado** em `secret/`
- [ ] **Security Group do EKS permite acesso da VM do Vault** (porta 443)
- [ ] **VM do Vault consegue acessar o K8s API**
- [ ] **Vault Agent Injector configurado com HTTPS**
- [ ] **Secret `admission-tls` criado no Vault**
- [ ] **Policies e roles criados no Vault**
- [ ] **Cluster credentials criados no Vault**

---

## 🧪 Testes de Conectividade

### Teste 1: Vault VM → Kubernetes API
```bash
ssh -i <key> ubuntu@<vault-ip> \
  "curl -k -m 5 https://<k8s-api-ip>:443/version"
```
**Esperado:** JSON com versão do Kubernetes

### Teste 2: Kubernetes → Vault
```bash
kubectl run test --rm -it --image=curlimages/curl -- \
  curl -k https://<vault-ip>:8200/v1/sys/health
```
**Esperado:** JSON com status do Vault

### Teste 3: Autenticação Vault
```bash
vault write auth/kubernetes/login \
  role=redis-enterprise-operator-redis-enterprise \
  jwt=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```
**Esperado:** Token criado com sucesso

---

## 📊 Logs Importantes

### Operator Admission (Sucesso)
```
{"level":"info","msg":"new Vault token was created"}
{"level":"info","msg":"TLS key successfully retrieved"}
{"level":"info","msg":"Starting HTTP server"}
```

### Vault Agent Init (Sucesso)
```
[INFO] agent.auth.handler: authentication successful, sending token to sinks
[INFO] agent.sink.file: token written: path=/home/vault/.vault-token
[INFO] agent: (runner) rendered "(dynamic)" => "/vault/secrets/rec.json"
```

---

## 🎯 Resultado Final

✅ **Operator:** 2/2 Running  
✅ **REC Pods:** 2/3 Running (rec-0 com problema de CPU, não relacionado ao Vault)  
✅ **Secrets injetados:** Verificado em `/vault/secrets/rec.json`  
✅ **Autenticação:** Funcionando perfeitamente

