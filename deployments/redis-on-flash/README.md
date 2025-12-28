# Redis on Flash (RoF)

Deploy Redis Enterprise with Redis on Flash para otimizar custos em datasets grandes usando tiering de memória RAM + SSD.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Quando Usar](#quando-usar)
- [Pré-requisitos](#pré-requisitos)
- [Guia de Deployment](#guia-de-deployment)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

### O que é Redis on Flash?

**Redis on Flash (RoF)** é uma tecnologia do Redis Enterprise que permite armazenar dados em **RAM + SSD** usando tiering inteligente:

- **Hot data** (dados frequentemente acessados) → **RAM** (latência ultra-baixa)
- **Warm data** (dados menos acessados) → **SSD/Flash** (latência baixa, custo reduzido)

### Benefícios

| Benefício | Descrição |
|-----------|-----------|
| **💰 Redução de Custos** | Até 70% de economia vs. RAM-only para datasets grandes |
| **📈 Maior Capacidade** | Datasets de TB com fração do custo de RAM |
| **⚡ Performance** | Hot data em RAM mantém latência sub-millisecond |
| **🔄 Tiering Automático** | Redis gerencia automaticamente hot/warm data |
| **🎯 Transparente** | Aplicação não precisa de mudanças |

### Casos de Uso Ideais

✅ **Session Store** com milhões de sessões (maioria inativa)  
✅ **Cache** com working set pequeno mas dataset total grande  
✅ **Time-Series** com dados recentes quentes e históricos frios  
✅ **Analytics** com queries em dados recentes  
✅ **Leaderboards** com milhões de usuários mas top-N acessado  

---

## 🏗️ Arquitetura

### Tiering de Dados

```
┌─────────────────────────────────────────────────────────────┐
│                    Redis on Flash                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  RAM Tier (Hot Data)                                 │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - Dados frequentemente acessados                    │   │
│  │  - Keys + valores pequenos                           │   │
│  │  - Latência: < 1ms                                   │   │
│  │  - Tamanho: 20-30% do dataset total                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                           ▲                                   │
│                           │ Automatic Tiering                 │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Flash/SSD Tier (Warm Data)                          │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - Dados menos acessados                             │   │
│  │  - Valores grandes                                   │   │
│  │  - Latência: 1-5ms                                   │   │
│  │  - Tamanho: 70-80% do dataset total                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Como Funciona

1. **Write**: Dados escritos primeiro em RAM
2. **Tiering**: Redis move valores grandes/frios para Flash automaticamente
3. **Read Hot**: Dados em RAM retornados imediatamente (< 1ms)
4. **Read Warm**: Dados em Flash carregados para RAM sob demanda (1-5ms)
5. **Eviction**: Dados antigos removidos do Flash conforme política

---

## ✅ Quando Usar

### ✅ Use Redis on Flash quando:

- Dataset total > 100GB
- Working set (hot data) < 30% do dataset total
- Valores grandes (> 1KB)
- Latência de 1-5ms é aceitável para warm data
- Custo é fator crítico

### ❌ NÃO use Redis on Flash quando:

- Dataset total < 50GB (RAM-only é mais simples)
- Working set > 50% do dataset (pouco benefício)
- Valores muito pequenos (< 100 bytes)
- Latência sub-millisecond é crítica para TODOS os dados
- Workload é 100% write-heavy

---

## ✅ Pré-requisitos

### 1. Storage Class com SSD/NVMe

Redis on Flash requer **SSD de alta performance** (NVMe recomendado):

```bash
kubectl get storageclass
# NAME                 PROVISIONER             RECLAIMPOLICY
# gp3-ssd             ebs.csi.aws.com         Delete
# premium-ssd-lrs     disk.csi.azure.com      Delete
# pd-ssd              pd.csi.storage.gke.io   Delete
```

### 2. Nodes com SSD Local (Opcional mas Recomendado)

Para máxima performance, use nodes com **SSD local** (instance store):

**AWS**: `i3`, `i3en`, `i4i` instances  
**Azure**: `Lsv2`, `Lsv3` series  
**GCP**: `n2-standard` com local SSD  

### 3. Redis Enterprise Cluster

```bash
kubectl get rec -n redis-enterprise
# NAME                  AGE
# redis-enterprise      10m
```

---

## 📖 Guia de Deployment

### Passo 1: Criar StorageClass para Flash

```bash
# Escolha o arquivo apropriado para seu cloud provider
kubectl apply -f 01-storage-class-aws.yaml      # AWS EBS gp3
# OU
kubectl apply -f 01-storage-class-azure.yaml    # Azure Premium SSD
# OU
kubectl apply -f 01-storage-class-gcp.yaml      # GCP PD-SSD
```

### Passo 2: Configurar REC com Flash Storage

```bash
kubectl apply -f 02-rec-with-flash.yaml
```

Este arquivo configura:
- **redisOnFlashSpec**: Habilita Redis on Flash
- **flashStorageEngine**: `rocksdb` (engine otimizado)
- **flashDiskSize**: Tamanho do SSD por pod (ex: 500Gi)
- **persistentSpec**: StorageClass para Flash volumes

### Passo 3: Criar REDB com Redis on Flash

```bash
kubectl apply -f 03-redb-with-flash.yaml
```

Configurações importantes:
- **memorySize**: RAM para hot data (ex: 10GB)
- **redisOnFlashSpec.flashDiskSize**: SSD para warm data (ex: 100GB)
- **Ratio**: 1:10 (10GB RAM + 100GB Flash = 110GB total)

### Passo 4: Verificar Deployment

```bash
# Verificar REC
kubectl get rec redis-enterprise-flash -n redis-enterprise

# Verificar PVCs de Flash
kubectl get pvc -n redis-enterprise | grep flash

# Verificar REDB
kubectl get redb flash-db-1 -n redis-enterprise
kubectl describe redb flash-db-1 -n redis-enterprise
```

---

## 🎯 Configurações Recomendadas

### Ratio RAM:Flash

| Workload | RAM | Flash | Ratio | Uso |
|----------|-----|-------|-------|-----|
| **Session Store** | 10GB | 90GB | 1:9 | Sessões antigas raramente acessadas |
| **Cache** | 20GB | 80GB | 1:4 | Working set médio |
| **Time-Series** | 15GB | 135GB | 1:9 | Dados recentes quentes |
| **Analytics** | 30GB | 120GB | 1:4 | Queries em dados recentes |

### Tamanho de Valores

| Tamanho Valor | Recomendação |
|---------------|--------------|
| < 500 bytes | ❌ RAM-only (RoF não compensa) |
| 500B - 5KB | ⚠️ Avaliar caso a caso |
| > 5KB | ✅ RoF ideal |

---

## 📊 Performance Tuning

Veja o arquivo [04-performance-tuning.md](./04-performance-tuning.md) para guia completo de tuning.

---

## 🔍 Troubleshooting

Veja o arquivo [05-troubleshooting.md](./05-troubleshooting.md) para guia completo de troubleshooting.

---

## 📚 Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `01-storage-class-aws.yaml` | StorageClass para AWS EBS gp3 |
| `01-storage-class-azure.yaml` | StorageClass para Azure Premium SSD |
| `01-storage-class-gcp.yaml` | StorageClass para GCP PD-SSD |
| `02-rec-with-flash.yaml` | REC configurado para Redis on Flash |
| `03-redb-with-flash.yaml` | REDB usando Redis on Flash |
| `04-performance-tuning.md` | Guia de performance tuning |
| `05-troubleshooting.md` | Guia de troubleshooting |

---

## 🔗 Referências

- [Redis on Flash Documentation](https://redis.io/docs/latest/operate/rs/databases/redis-on-flash/)
- [Redis on Flash Architecture](https://redis.io/docs/latest/operate/rs/databases/redis-on-flash/rof-architecture/)
- [Performance Optimization](https://redis.io/docs/latest/operate/rs/databases/redis-on-flash/rof-performance/)

