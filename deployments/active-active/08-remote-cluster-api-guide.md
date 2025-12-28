# Remote Cluster API (RERC) - Guia Completo

Documentação detalhada sobre RedisEnterpriseRemoteCluster (RERC) para Active-Active deployments.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Configuração](#configuração)
- [Casos de Uso](#casos-de-uso)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

### O que é RERC?

**RedisEnterpriseRemoteCluster (RERC)** é um Custom Resource Definition (CRD) que define a **conexão entre clusters Redis Enterprise** para Active-Active replication.

### Por que usar RERC?

✅ **Active-Active Replication**: Habilita replicação bidirecional entre clusters  
✅ **Geo-Distribution**: Conecta clusters em diferentes regiões/clouds  
✅ **Disaster Recovery**: Failover automático entre regiões  
✅ **Low Latency**: Aplicações leem/escrevem localmente  
✅ **Conflict Resolution**: CRDT resolve conflitos automaticamente  

### Componentes

| Componente | Descrição |
|------------|-----------|
| **RERC** | Define conexão com cluster remoto |
| **REC** | Cluster Redis Enterprise local |
| **REAADB** | Active-Active database que usa RERC |
| **Secret** | Credenciais para autenticação entre clusters |

---

## 🏗️ Arquitetura

### Fluxo de Comunicação

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cluster A                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ REC (rec-a)                                              │   │
│  │ - API Endpoint: api-rec-a.redis.example.com:9443         │   │
│  │ - DB Suffix: .db-rec-a.redis.example.com                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                       │
│                           │ Manages                               │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ RERC (rerc-a) - Local Cluster                            │   │
│  │ - recName: rec-a                                         │   │
│  │ - apiFqdnUrl: api-rec-a.redis.example.com                │   │
│  │ - dbFqdnSuffix: .db-rec-a.redis.example.com              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ RERC (rerc-b) - Remote Cluster                           │   │
│  │ - recName: rec-b                                         │   │
│  │ - apiFqdnUrl: api-rec-b.redis.example.com ───────────────┼───┐
│  │ - dbFqdnSuffix: .db-rec-b.redis.example.com              │   │
│  │ - secretName: redis-enterprise-rerc-b                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                       │
│                           │ Uses                                  │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ REAADB (aadb)                                            │   │
│  │ - participatingClusters:                                 │   │
│  │   - name: rerc-a                                         │   │
│  │   - name: rerc-b ─────────────────────────────────────────┼───┤
│  └──────────────────────────────────────────────────────────┘   │ │
│                                                                   │ │
└───────────────────────────────────────────────────────────────────┘ │
                                                                      │
                                                                      │
┌─────────────────────────────────────────────────────────────────┐ │
│                         Cluster B                                │ │
├─────────────────────────────────────────────────────────────────┤ │
│                                                                   │ │
│  ┌──────────────────────────────────────────────────────────┐   │ │
│  │ REC (rec-b)                                              │◄──┘ │
│  │ - API Endpoint: api-rec-b.redis.example.com:9443         │     │
│  │ - DB Suffix: .db-rec-b.redis.example.com                 │     │
│  └──────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Endpoints Necessários

Para Active-Active funcionar, os seguintes endpoints devem ser acessíveis:

| Endpoint | Porta | Protocolo | Uso |
|----------|-------|-----------|-----|
| **API FQDN** | 9443 | HTTPS | Gerenciamento do cluster |
| **DB FQDN** | 12000+ | TCP/TLS | Replicação de dados |

---

## ⚙️ Configuração

### 1. Estrutura Básica do RERC

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: rerc-remote
  namespace: redis-enterprise
spec:
  # Nome do REC remoto
  recName: rec-remote
  
  # Namespace do REC remoto
  recNamespace: redis-enterprise
  
  # API endpoint do cluster remoto
  apiFqdnUrl: api-rec-remote.redis.example.com
  
  # Sufixo para databases do cluster remoto
  dbFqdnSuffix: .db-rec-remote.redis.example.com
  
  # Secret com credenciais do cluster remoto
  secretName: redis-enterprise-rerc-remote
```

### 2. Secret para RERC

O secret deve conter as credenciais de admin do cluster remoto:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-enterprise-rerc-remote
  namespace: redis-enterprise
type: Opaque
stringData:
  username: admin@redis.com
  password: RedisAdmin123!
```

### 3. Usando RERC em REAADB

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseActiveActiveDatabase
metadata:
  name: aadb
  namespace: redis-enterprise
spec:
  participatingClusters:
    # Cluster local
    - name: rerc-local
    
    # Cluster remoto (definido via RERC)
    - name: rerc-remote
  
  globalConfigurations:
    memorySize: 2GB
    replication: true
```

---

## 🎯 Casos de Uso

### 1. Active-Active entre 2 Regiões

**Cenário**: E-commerce com usuários em US-East e EU-West.

**Configuração**:
```yaml
# Cluster US-East
---
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: rerc-us-east
spec:
  recName: rec-us-east
  apiFqdnUrl: api-us-east.redis.example.com
  dbFqdnSuffix: .db-us-east.redis.example.com
  secretName: rerc-us-east-secret

---
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: rerc-eu-west
spec:
  recName: rec-eu-west
  apiFqdnUrl: api-eu-west.redis.example.com
  dbFqdnSuffix: .db-eu-west.redis.example.com
  secretName: rerc-eu-west-secret
```

### 2. Active-Active entre 3+ Regiões

**Cenário**: Global application com usuários em US, EU, APAC.

**Configuração**:
```yaml
# REAADB com 3 clusters
spec:
  participatingClusters:
    - name: rerc-us-east
    - name: rerc-eu-west
    - name: rerc-apac-south
```

### 3. Hybrid Cloud (AWS + Azure + GCP)

**Cenário**: Multi-cloud deployment para evitar vendor lock-in.

**Configuração**:
```yaml
# Cluster AWS
- name: rerc-aws-us-east-1
  apiFqdnUrl: api-aws.redis.example.com

# Cluster Azure
- name: rerc-azure-eastus
  apiFqdnUrl: api-azure.redis.example.com

# Cluster GCP
- name: rerc-gcp-us-central1
  apiFqdnUrl: api-gcp.redis.example.com
```

---

## 🔍 Troubleshooting

### 1. RERC não conecta ao cluster remoto

**Sintoma**:
```bash
kubectl describe rerc rerc-b -n redis-enterprise
# Status: Error
# Message: Failed to connect to remote cluster
```

**Verificar**:
```bash
# Testar conectividade ao API endpoint
curl -k https://api-rec-b.redis.example.com:9443/v1/cluster

# Verificar secret
kubectl get secret redis-enterprise-rerc-b -n redis-enterprise -o yaml
```

**Soluções**:
- Verificar firewall/security groups (porta 9443)
- Verificar DNS resolution do FQDN
- Verificar credenciais no secret

### 2. Replicação não funciona

**Sintoma**: Dados escritos em Cluster A não aparecem em Cluster B.

**Verificar**:
```bash
# Status do REAADB
kubectl describe reaadb aadb -n redis-enterprise

# Logs do operator
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

**Soluções**:
- Verificar conectividade na porta do database (12000+)
- Verificar `dbFqdnSuffix` está correto
- Verificar firewall permite tráfego entre clusters

### 3. REAADB fica em "Pending"

**Sintoma**:
```bash
kubectl get reaadb -n redis-enterprise
# NAME   STATUS    AGE
# aadb   Pending   5m
```

**Verificar**:
```bash
# Verificar se todos os RERC estão prontos
kubectl get rerc -n redis-enterprise

# Verificar eventos
kubectl describe reaadb aadb -n redis-enterprise
```

**Soluções**:
- Garantir que todos os RERC estão em estado "Active"
- Verificar que REC tem recursos suficientes
- Verificar logs do operator

---

## 📚 Referências

- [Active-Active Documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [RERC API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/redis-enterprise-remote-cluster/)
- [REAADB API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/redis-enterprise-active-active-database/)

