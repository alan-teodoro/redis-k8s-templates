# Redis on Flash - Troubleshooting

Guia completo de troubleshooting para Redis on Flash.

---

## 🔍 Problemas Comuns

### 1. REDB não inicia com Redis on Flash

**Sintoma**:
```bash
kubectl get redb flash-db-1 -n redis-enterprise
# NAME         STATUS    AGE
# flash-db-1   Pending   5m
```

**Verificar**:
```bash
# Verificar eventos
kubectl describe redb flash-db-1 -n redis-enterprise

# Verificar logs do operator
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

**Causas possíveis**:

#### A) REC não tem Redis on Flash habilitado

**Verificar**:
```bash
kubectl get rec redis-enterprise-flash -n redis-enterprise -o yaml | grep -A5 redisOnFlashSpec
```

**Solução**:
```bash
# Editar REC para habilitar RoF
kubectl edit rec redis-enterprise-flash -n redis-enterprise

# Adicionar:
spec:
  redisOnFlashSpec:
    enabled: true
    flashStorageEngine: rocksdb
    flashDiskSize: 500Gi
```

#### B) PVC não pode ser criado (StorageClass não existe)

**Verificar**:
```bash
kubectl get storageclass
kubectl get pvc -n redis-enterprise | grep flash
```

**Solução**:
```bash
# Criar StorageClass apropriado
kubectl apply -f 01-storage-class-aws.yaml  # ou azure/gcp
```

#### C) Nodes não têm espaço suficiente

**Verificar**:
```bash
kubectl describe nodes | grep -A5 "Allocated resources"
```

**Solução**:
Adicionar mais nodes ou reduzir `flashDiskSize`.

---

### 2. Performance ruim (latência alta)

**Sintoma**:
```bash
redis-cli --latency -h flash-db-1 -p 12000
# min: 1, max: 50, avg: 10.23 (ms)  # Muito alto!
```

**Verificar**:

#### A) RAM Hit Ratio baixo

**Verificar**:
```bash
redis-cli -h flash-db-1 -p 12000 INFO stats | grep keyspace
# keyspace_hits:1000
# keyspace_misses:9000
# Hit ratio = 10% (muito baixo!)
```

**Solução**:
```bash
# Aumentar memorySize
kubectl edit redb flash-db-1 -n redis-enterprise

spec:
  memorySize: 20GB  # Era 10GB
```

#### B) SSD lento (IOPS insuficiente)

**Verificar**:
```bash
# Verificar StorageClass
kubectl get storageclass redis-flash-gp3 -o yaml

# Verificar IOPS provisionados
# AWS: parameters.iops
# Azure: parameters.diskIOPSReadWrite
# GCP: parameters.provisioned-iops-on-create
```

**Solução**:
```bash
# Aumentar IOPS no StorageClass
kubectl edit storageclass redis-flash-gp3

parameters:
  iops: "16000"  # Era 3000
  throughput: "1000"  # Era 125
```

#### C) Compactação do RocksDB

**Verificar**:
```bash
# Conectar ao REC pod
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash

# Verificar status de compactação
rladmin status databases extra all | grep compaction
```

**Solução**:
```bash
# Forçar compactação manual
rladmin tune db db:1 rocksdb_compact_now
```

---

### 3. Flash disk cheio

**Sintoma**:
```bash
# Erro: "Flash disk full"
kubectl logs -n redis-enterprise redis-enterprise-flash-0 | grep -i "flash.*full"
```

**Verificar**:
```bash
# Verificar uso de Flash
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash
df -h | grep flash

# Verificar tamanho do database
rladmin status databases extra all
```

**Causas possíveis**:

#### A) flashDiskSize muito pequeno

**Solução**:
```bash
# Aumentar flashDiskSize
kubectl edit redb flash-db-1 -n redis-enterprise

spec:
  redisOnFlashSpec:
    flashDiskSize: 200GB  # Era 100GB
```

#### B) Eviction policy inadequada

**Solução**:
```bash
# Mudar eviction policy
kubectl edit redb flash-db-1 -n redis-enterprise

spec:
  evictionPolicy: allkeys-lru  # Era noeviction
```

#### C) Compactação não está funcionando

**Solução**:
```bash
# Forçar compactação
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash
rladmin tune db db:1 rocksdb_compact_now
```

---

### 4. PVC não é criado

**Sintoma**:
```bash
kubectl get pvc -n redis-enterprise
# No resources found
```

**Verificar**:
```bash
# Verificar eventos
kubectl get events -n redis-enterprise --sort-by='.lastTimestamp' | grep -i pvc

# Verificar StorageClass
kubectl get storageclass
```

**Causas possíveis**:

#### A) StorageClass não existe

**Solução**:
```bash
kubectl apply -f 01-storage-class-aws.yaml
```

#### B) Quota de storage excedida

**Verificar**:
```bash
kubectl describe resourcequota -n redis-enterprise
```

**Solução**:
Aumentar quota ou deletar PVCs não usados.

#### C) Provisioner não está funcionando

**Verificar**:
```bash
# AWS
kubectl get pods -n kube-system | grep ebs-csi

# Azure
kubectl get pods -n kube-system | grep disk-csi

# GCP
kubectl get pods -n kube-system | grep pd-csi
```

**Solução**:
Instalar/reiniciar CSI driver apropriado.

---

### 5. Database não usa Flash (só RAM)

**Sintoma**:
```bash
# Database usa apenas RAM, não Flash
rladmin status databases extra all
# flash_used: 0
```

**Verificar**:
```bash
# Verificar configuração do REDB
kubectl get redb flash-db-1 -n redis-enterprise -o yaml | grep -A5 redisOnFlashSpec
```

**Causas possíveis**:

#### A) redisOnFlashSpec não habilitado no REDB

**Solução**:
```bash
kubectl edit redb flash-db-1 -n redis-enterprise

spec:
  redisOnFlashSpec:
    enabled: true
    flashDiskSize: 100GB
```

#### B) Valores muito pequenos (< 500 bytes)

**Explicação**: Redis on Flash só move valores grandes para Flash.

**Solução**: Use valores > 1KB para se beneficiar de RoF.

---

## 🔧 Comandos Úteis

### Verificar status de Flash

```bash
# Conectar ao REC pod
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash

# Status de databases
rladmin status databases extra all

# Uso de Flash
rladmin status nodes extra all | grep flash

# Configurações de RocksDB
rladmin info db db:1 | grep rocksdb
```

### Verificar PVCs de Flash

```bash
# Listar PVCs
kubectl get pvc -n redis-enterprise | grep flash

# Detalhes de PVC
kubectl describe pvc redis-enterprise-flash-0-flash -n redis-enterprise

# Uso de disco
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- df -h | grep flash
```

### Forçar compactação

```bash
kubectl exec -it redis-enterprise-flash-0 -n redis-enterprise -- bash
rladmin tune db db:1 rocksdb_compact_now
```

### Verificar latência

```bash
# Latência contínua
redis-cli --latency -h flash-db-1 -p 12000

# Latência histórica
redis-cli --latency-history -h flash-db-1 -p 12000

# Latência por comando
redis-cli --latency-dist -h flash-db-1 -p 12000
```

---

## 📚 Referências

- [Redis on Flash Troubleshooting](https://redis.io/docs/latest/operate/rs/databases/redis-on-flash/)
- [RocksDB Troubleshooting](https://github.com/facebook/rocksdb/wiki/RocksDB-FAQ)

