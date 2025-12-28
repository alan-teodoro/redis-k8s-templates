# Exemplos de Uso do Log Collector

Este documento contém exemplos práticos de uso do log collector em diferentes cenários.

---

## 📋 Índice

- [Cenários Básicos](#cenários-básicos)
- [Cenários Avançados](#cenários-avançados)
- [Cenários de Produção](#cenários-de-produção)
- [Troubleshooting Específico](#troubleshooting-específico)

---

## 🎯 Cenários Básicos

### 1. Coleta Simples (Namespace Atual)

```bash
# Download do script
curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py

# Executar (usa namespace do contexto kubectl atual)
python3 log_collector.py

# Resultado
# Arquivo: redis_enterprise_k8s_debug_info_<timestamp>.tar.gz
```

### 2. Coleta de Namespace Específico

```bash
# Coletar do namespace redis-enterprise
python3 log_collector.py -n redis-enterprise

# Coletar de múltiplos namespaces
python3 log_collector.py -n redis-enterprise,redis-prod,redis-dev
```

### 3. Coleta com Saída Customizada

```bash
# Especificar diretório de saída
python3 log_collector.py -n redis-enterprise -o /tmp/redis-logs

# Verificar arquivo gerado
ls -lh /tmp/redis-logs/redis_enterprise_k8s_debug_info_*.tar.gz
```

---

## 🔧 Cenários Avançados

### 4. Coleta Completa (Modo All)

```bash
# Coletar TODOS os recursos do namespace
python3 log_collector.py -n redis-enterprise --mode all

# ⚠️ Mais lento, mas mais completo
# Útil quando o problema não está claro
```

### 5. Coleta com Istio

```bash
# Coletar informações do Istio junto com Redis
python3 log_collector.py -n redis-enterprise --collect_istio

# Útil quando usar Istio Service Mesh
```

### 6. Coleta por Helm Release

```bash
# Coletar apenas recursos de um Helm release específico
python3 log_collector.py --helm_release_name redis-enterprise

# Útil em ambientes com múltiplas instalações
```

### 7. Coleta com Timeout Customizado

```bash
# Aumentar timeout para ambientes grandes (padrão: 180s)
python3 log_collector.py -n redis-enterprise -t 300

# Desabilitar timeout (não recomendado)
python3 log_collector.py -n redis-enterprise -t 0
```

---

## 🏭 Cenários de Produção

### 8. Coleta Multi-Namespace (Produção)

```bash
# Coletar de todos os namespaces de produção
python3 log_collector.py \
  -n redis-prod-us-east,redis-prod-us-west,redis-prod-eu \
  -o /var/log/redis-support \
  -t 300

# Compactar ainda mais (opcional)
cd /var/log/redis-support
gzip redis_enterprise_k8s_debug_info_*.tar.gz
```

### 9. Coleta Agendada (Cron)

```bash
# Criar script de coleta agendada
cat > /usr/local/bin/redis-log-collect.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d)
OUTPUT_DIR="/var/log/redis-collector/${DATE}"
mkdir -p "${OUTPUT_DIR}"

python3 /opt/log_collector.py \
  -n redis-enterprise \
  -o "${OUTPUT_DIR}" \
  -t 300

# Manter apenas últimos 7 dias
find /var/log/redis-collector -type d -mtime +7 -exec rm -rf {} \;
EOF

chmod +x /usr/local/bin/redis-log-collect.sh

# Adicionar ao cron (diariamente às 2am)
echo "0 2 * * * /usr/local/bin/redis-log-collect.sh" | crontab -
```

### 10. Coleta com ServiceAccount

```bash
# Aplicar RBAC
kubectl apply -f 01-rbac-restricted.yaml

# Criar pod para executar log collector
kubectl run redis-log-collector \
  --image=python:3.11-slim \
  --serviceaccount=redis-log-collector \
  --restart=Never \
  --rm -it \
  --namespace=redis-enterprise \
  -- bash -c "
    pip install pyyaml && \
    curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py && \
    python3 log_collector.py -n redis-enterprise
  "
```

---

## 🔍 Troubleshooting Específico

### 11. Problema com Operator

```bash
# Coletar logs focados no operator
python3 log_collector.py \
  -n redis-enterprise \
  --mode restricted \
  -o /tmp/operator-issue

# Extrair e verificar logs do operator
cd /tmp/operator-issue
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
cat */pods/redis-enterprise-operator-*/logs.txt
```

### 12. Problema com Database Específico

```bash
# Coletar logs de namespace específico
python3 log_collector.py -n redis-enterprise

# Extrair e buscar por database específico
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
grep -r "redis-db-prod" */
```

### 13. Problema de Performance

```bash
# Coletar com modo all para análise completa
python3 log_collector.py \
  -n redis-enterprise \
  --mode all \
  -a \
  -t 600

# -a: logs de todos os pods
# -t 600: timeout de 10 minutos
```

### 14. Problema de Rede/Istio

```bash
# Coletar com informações de Istio
python3 log_collector.py \
  -n redis-enterprise \
  --collect_istio \
  --mode all

# Útil para problemas de conectividade
```

---

## 📤 Envio ao Suporte

### Preparar Arquivo para Envio

```bash
# 1. Localizar arquivo
ls -lh redis_enterprise_k8s_debug_info_*.tar.gz

# 2. Verificar tamanho
du -h redis_enterprise_k8s_debug_info_*.tar.gz

# 3. Se muito grande, compactar mais
gzip redis_enterprise_k8s_debug_info_*.tar.gz
# Resultado: redis_enterprise_k8s_debug_info_*.tar.gz.gz

# 4. Upload para suporte (exemplo com curl)
curl -F "file=@redis_enterprise_k8s_debug_info_*.tar.gz" \
     -F "ticket=TICKET-12345" \
     https://support.redis.com/upload
```

---

## 🔐 Uso com RBAC

### Verificar Permissões

```bash
# Verificar se você tem permissões necessárias
kubectl auth can-i get pods -n redis-enterprise
kubectl auth can-i get logs -n redis-enterprise
kubectl auth can-i list redisenterpriseclusters -n redis-enterprise

# Se não tiver, aplicar RBAC
kubectl apply -f 01-rbac-restricted.yaml

# Criar binding para seu usuário
kubectl create clusterrolebinding my-log-collector \
  --clusterrole=redis-log-collector-restricted \
  --user=$(kubectl config view -o jsonpath='{.users[0].name}')
```

---

## 📊 Análise do Arquivo Coletado

### Estrutura do Arquivo

```bash
# Extrair arquivo
tar -xzf redis_enterprise_k8s_debug_info_20231215_143022.tar.gz

# Estrutura típica:
redis_enterprise_k8s_debug_info_20231215_143022/
├── cluster_info/
│   ├── nodes.yaml
│   ├── storageclasses.yaml
│   └── namespaces.yaml
├── pods/
│   ├── redis-enterprise-operator-xxx/
│   │   ├── describe.yaml
│   │   └── logs.txt
│   └── rec-redis-enterprise-0/
│       ├── describe.yaml
│       └── logs.txt
├── services/
├── configmaps/
├── secrets/
├── custom_resources/
│   ├── redisenterpriseclusters.yaml
│   └── redisenterprisedatabases.yaml
└── events.yaml
```

### Comandos Úteis de Análise

```bash
# Buscar erros nos logs
grep -r "ERROR\|FATAL\|CRITICAL" */

# Buscar warnings
grep -r "WARN" */

# Verificar eventos
cat */events.yaml | grep -A 5 "Warning"

# Verificar status do REC
cat */custom_resources/redisenterpriseclusters.yaml | grep -A 20 "status:"
```

---

## 🔗 Referências

- [Documentação Oficial - Collect Logs](https://redis.io/docs/latest/operate/kubernetes/logs/collect-logs/)
- [Redis Enterprise K8s Docs](https://github.com/RedisLabs/redis-enterprise-k8s-docs)

