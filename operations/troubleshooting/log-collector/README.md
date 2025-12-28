# Redis Enterprise Log Collector

O **Log Collector** é uma ferramenta oficial do Redis Enterprise que coleta logs e informações de diagnóstico do seu ambiente Kubernetes para facilitar o troubleshooting com o suporte do Redis.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Modos de Operação](#modos-de-operação)
- [Guia de Uso](#guia-de-uso)
- [Opções Disponíveis](#opções-disponíveis)
- [RBAC Necessário](#rbac-necessário)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

### O que é o Log Collector?

O **log_collector.py** é um script Python oficial do Redis Enterprise que:

- ✅ Coleta logs de todos os componentes do Redis Enterprise (Operator, REC, REDB)
- ✅ Coleta informações de recursos do Kubernetes (pods, services, configmaps, etc.)
- ✅ Empacota tudo em um arquivo `.tar.gz` para envio ao suporte
- ✅ Suporta coleta de múltiplos namespaces
- ✅ Pode coletar informações de Istio (se usado)

### Quando Usar?

Use o log collector quando:

- 🔴 Tiver problemas com o Redis Enterprise Operator
- 🔴 Databases não estiverem funcionando corretamente
- 🔴 Precisar abrir um ticket com o suporte do Redis
- 🔴 Quiser fazer análise detalhada de problemas de produção

---

## ✅ Pré-requisitos

### 1. Python 3.6+

```bash
python3 --version
# Python 3.6 ou superior
```

### 2. Módulo PyYAML

```bash
pip3 install pyyaml
```

### 3. kubectl ou oc CLI

```bash
kubectl version --client
# ou
oc version --client
```

### 4. RBAC Permissions

O usuário que executar o script precisa ter permissões RBAC adequadas. Veja [RBAC Necessário](#rbac-necessário).

---

## 🔧 Modos de Operação

O log collector tem **2 modos**:

### 1. Modo `restricted` (Padrão - Recomendado)

Coleta **apenas** recursos criados pelo Operator e Redis Enterprise:

- ✅ Pods com label `app=redis-enterprise`
- ✅ Resources gerenciados pelo Operator
- ✅ Logs do Operator e REC/REDB
- ✅ **Mais rápido e focado**

```bash
python3 log_collector.py --mode restricted
```

### 2. Modo `all` (Completo)

Coleta **todos** os recursos do namespace:

- ✅ Todos os pods do namespace
- ✅ Todos os recursos (services, configmaps, secrets, etc.)
- ✅ **Mais lento, mas mais completo**

```bash
python3 log_collector.py --mode all
```

---

## 📖 Guia de Uso

### Uso Básico

```bash
# 1. Download do script
curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py

# 2. Executar (usa namespace do contexto atual)
python3 log_collector.py

# 3. Resultado
# Arquivo: redis_enterprise_k8s_debug_info_<timestamp>.tar.gz
```

### Especificar Namespace

```bash
# Single namespace
python3 log_collector.py -n redis-enterprise

# Multiple namespaces
python3 log_collector.py -n redis-enterprise,redis-prod,redis-dev
```

### Especificar Diretório de Saída

```bash
python3 log_collector.py -o /tmp/redis-logs
```

### Coletar de Todos os Pods

```bash
python3 log_collector.py -a
# ou
python3 log_collector.py --logs_from_all_pods
```

### Coletar Informações do Istio

```bash
python3 log_collector.py --collect_istio
```

### Coletar por Helm Release

```bash
python3 log_collector.py --helm_release_name redis-enterprise
```

---

## ⚙️ Opções Disponíveis

| Opção | Descrição | Padrão |
|-------|-----------|--------|
| `-n, --namespace` | Namespace(s) para coletar (separados por vírgula) | Namespace do contexto atual |
| `-o, --output_dir` | Diretório de saída | Diretório atual |
| `-a, --logs_from_all_pods` | Coletar logs de todos os pods | `false` |
| `-t, --timeout` | Timeout para comandos externos (segundos) | `180` |
| `--k8s_cli` | CLI do K8s (`kubectl`/`oc`/`auto-detect`) | `auto-detect` |
| `-m, --mode` | Modo de coleta (`restricted`/`all`) | `restricted` |
| `--collect_istio` | Coletar dados do namespace `istio-system` | `false` |
| `--collect_empty_files` | Coletar arquivos vazios para recursos faltantes | `false` |
| `--helm_release_name` | Coletar recursos do Helm release especificado | - |
| `--collect_rbac_resources` | Coletar recursos RBAC (flag de desenvolvimento) | `false` |
| `-h, --help` | Mostrar ajuda | - |

---

## 🔐 RBAC Necessário

### Para Modo `restricted` (Mínimo)

Veja o arquivo `01-rbac-restricted.yaml` para configuração completa.

**Permissões necessárias:**
- `get`, `list` em pods, services, configmaps, secrets
- `get`, `list` em CRDs (REC, REDB, RERC, REAADB)
- `get` logs de pods

### Para Modo `all` (Completo)

Veja o arquivo `02-rbac-all.yaml` para configuração completa.

**Permissões adicionais:**
- `get`, `list` em **todos** os recursos do namespace
- `get`, `list` em nodes (cluster-scoped)

---

## 🔍 Troubleshooting

### Erro: `ModuleNotFoundError: No module named 'yaml'`

**Solução:**
```bash
pip3 install pyyaml
```

### Erro: `Permission denied`

**Causa:** RBAC insuficiente

**Solução:**
```bash
# Verificar permissões
kubectl auth can-i get pods -n redis-enterprise
kubectl auth can-i get logs -n redis-enterprise

# Aplicar RBAC adequado
kubectl apply -f 01-rbac-restricted.yaml
```

### Timeout em Comandos

**Solução:**
```bash
# Aumentar timeout (padrão: 180s)
python3 log_collector.py -t 300

# Desabilitar timeout
python3 log_collector.py -t 0
```

### Script Não Encontra kubectl/oc

**Solução:**
```bash
# Especificar caminho completo
python3 log_collector.py --k8s_cli /usr/local/bin/kubectl
```

---

## 📦 O que é Coletado?

### Logs
- Operator logs
- REC pod logs
- REDB pod logs
- Services pod logs

### Recursos Kubernetes
- Pods, Services, ConfigMaps, Secrets
- PersistentVolumeClaims, PersistentVolumes
- StatefulSets, Deployments
- Custom Resources (REC, REDB, RERC, REAADB)

### Informações do Cluster
- Node information
- Storage classes
- Network policies
- Ingress/Routes

---

## 📤 Envio ao Suporte

Após coletar os logs:

1. **Localize o arquivo gerado:**
   ```bash
   ls -lh redis_enterprise_k8s_debug_info_*.tar.gz
   ```

2. **Envie ao suporte do Redis:**
   - Via ticket de suporte
   - Via email (se solicitado)
   - Via portal de suporte

3. **Informações adicionais:**
   - Descrição do problema
   - Passos para reproduzir
   - Quando o problema começou

---

## 🔗 Referências

- [Documentação Oficial - Collect Logs](https://redis.io/docs/latest/operate/kubernetes/logs/collect-logs/)
- [Redis Enterprise K8s Docs - Log Collector](https://github.com/RedisLabs/redis-enterprise-k8s-docs/tree/master/log_collector)
- [RBAC Examples](https://redis.io/docs/latest/operate/kubernetes/logs/log-collector-rbac/)

