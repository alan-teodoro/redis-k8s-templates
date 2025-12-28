# Redis on Flash - Performance Tuning

Guia completo de otimização de performance para Redis on Flash.

---

## 🎯 Princípios de Performance

### 1. Maximize Hot Data em RAM

**Objetivo**: Manter dados frequentemente acessados em RAM.

**Estratégias**:
- **Ratio RAM:Flash adequado**: 1:5 a 1:10 dependendo do workload
- **Working set < 30% do dataset**: Ideal para RoF
- **TTL em dados antigos**: Força eviction de dados frios

**Exemplo**:
```yaml
spec:
  memorySize: 20GB      # Hot data
  redisOnFlashSpec:
    flashDiskSize: 100GB  # Warm data (ratio 1:5)
```

### 2. Use SSD de Alta Performance

**Recomendações por Cloud Provider**:

| Provider | Recomendado | IOPS | Throughput |
|----------|-------------|------|------------|
| **AWS** | io2 / gp3 | 16000-64000 | 1000 MB/s |
| **Azure** | Premium SSD / Ultra SSD | 20000-160000 | 900-4000 MB/s |
| **GCP** | pd-ssd / pd-extreme | 15000-120000 | 240-1200 MB/s |

**Melhor opção**: Local NVMe SSD (i3/i4i, Lsv2/Lsv3, local-ssd)

### 3. Otimize Tamanho de Valores

**Performance por Tamanho**:

| Tamanho | RAM Hit | Flash Hit | Recomendação |
|---------|---------|-----------|--------------|
| < 500B | < 1ms | 2-5ms | ❌ Use RAM-only |
| 500B-5KB | < 1ms | 1-3ms | ⚠️ Avaliar |
| > 5KB | < 1ms | 1-2ms | ✅ RoF ideal |

**Estratégia**: Valores grandes (> 5KB) se beneficiam mais de RoF.

---

## ⚙️ Configurações de Tuning

### 1. RocksDB Tuning

RocksDB é o storage engine padrão para Redis on Flash.

**Configurações importantes** (via `rladmin`):

```bash
# Conectar ao REC pod
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash

# Configurar block cache (cache de blocos do RocksDB)
rladmin tune db db:1 rocksdb_block_cache_size 2GB

# Configurar write buffer (buffer de escrita)
rladmin tune db db:1 rocksdb_write_buffer_size 256MB

# Configurar max write buffers
rladmin tune db db:1 rocksdb_max_write_buffer_number 4

# Configurar compaction threads
rladmin tune db db:1 rocksdb_max_background_compactions 4
```

### 2. Eviction Policy

**Políticas recomendadas para RoF**:

| Workload | Eviction Policy | Motivo |
|----------|----------------|--------|
| **Session Store** | `volatile-lru` | Remove sessões antigas com TTL |
| **Cache** | `allkeys-lru` | Remove qualquer chave antiga |
| **Time-Series** | `volatile-ttl` | Remove dados com TTL mais curto |
| **Analytics** | `allkeys-lru` | Remove dados menos acessados |

**Configuração**:
```yaml
spec:
  evictionPolicy: volatile-lru
```

### 3. Sharding

**Quando usar sharding com RoF**:
- Dataset > 100GB
- Workload write-heavy
- Necessidade de paralelização

**Recomendações**:
```yaml
spec:
  shardCount: 3  # 1 shard por 50-100GB de dados
```

**Cálculo**:
- Dataset 150GB → 3 shards (50GB cada)
- Dataset 300GB → 6 shards (50GB cada)

---

## 📊 Monitoramento de Performance

### 1. Métricas Críticas

**RAM Hit Ratio**:
```bash
# Deve ser > 80% para boa performance
redis-cli INFO stats | grep keyspace_hits
redis-cli INFO stats | grep keyspace_misses
# Hit ratio = hits / (hits + misses)
```

**Flash Hit Ratio**:
```bash
# Verificar via Redis Enterprise UI ou API
# Deve ser > 90%
```

**Latência**:
```bash
# Latência média deve ser < 2ms
redis-cli --latency-history -h flash-db-1 -p 12000
```

### 2. Alertas Recomendados

| Métrica | Threshold | Ação |
|---------|-----------|------|
| RAM Hit Ratio | < 80% | Aumentar RAM ou otimizar queries |
| Flash Hit Ratio | < 90% | Aumentar Flash ou revisar eviction |
| Latência P99 | > 5ms | Verificar SSD performance |
| Flash Disk Usage | > 85% | Aumentar Flash size |

---

## 🚀 Otimizações Avançadas

### 1. Compactação de Dados

**Use compressão para valores grandes**:
```bash
# Habilitar compressão (via rladmin)
rladmin tune db db:1 data_compression enabled
```

**Benefícios**:
- Reduz uso de Flash em 30-50%
- Aumenta throughput de I/O
- Trade-off: +10-20% CPU

### 2. Pré-aquecimento de Cache

**Estratégia**: Carregar hot data na inicialização.

```python
# Exemplo: Pré-carregar top 10000 keys
import redis

r = redis.Redis(host='flash-db-1', port=12000)

# Obter top keys (via SCAN)
hot_keys = []
for key in r.scan_iter(count=10000):
    hot_keys.append(key)

# Acessar keys para carregar em RAM
for key in hot_keys:
    r.get(key)
```

### 3. Batch Operations

**Use pipelines para reduzir latência**:
```python
import redis

r = redis.Redis(host='flash-db-1', port=12000)

# Sem pipeline: N round-trips
for i in range(1000):
    r.get(f'key:{i}')  # 1000 round-trips

# Com pipeline: 1 round-trip
pipe = r.pipeline()
for i in range(1000):
    pipe.get(f'key:{i}')
pipe.execute()  # 1 round-trip
```

---

## 📈 Benchmarking

### 1. redis-benchmark

```bash
# Benchmark básico
redis-benchmark -h flash-db-1 -p 12000 -t get,set -n 100000 -d 1024

# Benchmark com valores grandes (10KB)
redis-benchmark -h flash-db-1 -p 12000 -t get,set -n 100000 -d 10240

# Benchmark com pipeline
redis-benchmark -h flash-db-1 -p 12000 -t get,set -n 100000 -d 1024 -P 16
```

### 2. Resultados Esperados

| Operação | Valor | Latência | Throughput |
|----------|-------|----------|------------|
| GET (RAM hit) | 1KB | < 1ms | 100K ops/s |
| GET (Flash hit) | 1KB | 1-2ms | 50K ops/s |
| GET (RAM hit) | 10KB | < 1ms | 50K ops/s |
| GET (Flash hit) | 10KB | 2-3ms | 20K ops/s |
| SET | 1KB | < 1ms | 80K ops/s |
| SET | 10KB | 1-2ms | 40K ops/s |

---

## 🔗 Referências

- [Redis on Flash Performance](https://redis.io/docs/latest/operate/rs/databases/redis-on-flash/rof-performance/)
- [RocksDB Tuning Guide](https://github.com/facebook/rocksdb/wiki/RocksDB-Tuning-Guide)

