# Performance Testing for Redis Enterprise on Kubernetes

Comprehensive guide for performance testing and benchmarking Redis Enterprise deployments.

## 📋 Table of Contents

- [Overview](#overview)
- [Files in this Directory](#files-in-this-directory)
- [Testing Tools](#testing-tools)
- [Benchmarking](#benchmarking)
- [Load Testing](#load-testing)
- [Performance Tuning](#performance-tuning)
- [Metrics to Monitor](#metrics-to-monitor)

---

## 📁 Files in this Directory

| File | Description |
|------|-------------|
| `01-memtier-benchmark-pod.yaml` | Interactive memtier_benchmark pod |
| `02-memtier-benchmark-job.yaml` | Automated memtier_benchmark job |
| `03-redis-benchmark-pod.yaml` | Interactive redis-benchmark pod |

---

## 🎯 Overview

Performance testing ensures:
- ✅ Meeting SLA requirements
- ✅ Identifying bottlenecks
- ✅ Validating capacity planning
- ✅ Optimizing resource usage

**Key Metrics:**
- **Throughput**: Operations per second (OPS)
- **Latency**: Response time (p50, p95, p99)
- **Resource Usage**: CPU, memory, network
- **Scalability**: Performance under load

---

## 🔧 Testing Tools

### 1. redis-benchmark (Built-in)

**Best for:** Quick baseline testing

```bash
# Deploy redis-benchmark pod
kubectl apply -f 03-redis-benchmark-pod.yaml

# Exec into pod
kubectl exec -it redis-benchmark -n redis-enterprise -- bash

# Inside the pod:
redis-benchmark -h redis-db.redis-enterprise.svc.cluster.local -p 12000 \
  -c 50 -n 100000 -d 1024 -t get,set
```

**Parameters:**
- `-c`: Number of parallel connections
- `-n`: Total number of requests
- `-d`: Data size in bytes
- `-t`: Tests to run (get, set, lpush, etc.)

### 2. memtier_benchmark (Recommended)

**Best for:** Comprehensive testing with realistic workloads

**Option A: Interactive Pod**
```bash
# Deploy memtier_benchmark pod
kubectl apply -f 01-memtier-benchmark-pod.yaml

# Exec into pod
kubectl exec -it memtier-benchmark -n redis-enterprise -- bash

# Inside the pod:
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=50 \
  --threads=4 \
  --requests=10000 \
  --data-size=1024 \
  --key-pattern=R:R \
  --ratio=1:1
```

**Option B: Automated Job**
```bash
# Deploy and run automated test
kubectl apply -f 02-memtier-benchmark-job.yaml

# Watch logs
kubectl logs -f job/memtier-benchmark-job -n redis-enterprise

# Clean up
kubectl delete job memtier-benchmark-job -n redis-enterprise
```

**Parameters:**
- `--clients`: Clients per thread
- `--threads`: Number of threads
- `--requests`: Requests per client
- `--data-size`: Value size in bytes
- `--key-pattern`: Key distribution (R:R = random)
- `--ratio`: GET:SET ratio (1:1 = 50% reads, 50% writes)

### 3. YCSB (Yahoo! Cloud Serving Benchmark)

**Best for:** Simulating real-world application workloads

```bash
# Download YCSB
curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz
tar xfvz ycsb-0.17.0.tar.gz
cd ycsb-0.17.0

# Load data
./bin/ycsb load redis -s -P workloads/workloada \
  -p "redis.host=redis-db.redis-enterprise.svc.cluster.local" \
  -p "redis.port=12000"

# Run workload
./bin/ycsb run redis -s -P workloads/workloada \
  -p "redis.host=redis-db.redis-enterprise.svc.cluster.local" \
  -p "redis.port=12000"
```

**Workloads:**
- **Workload A**: 50% reads, 50% updates
- **Workload B**: 95% reads, 5% updates
- **Workload C**: 100% reads
- **Workload D**: 95% reads, 5% inserts
- **Workload E**: 95% scans, 5% inserts
- **Workload F**: 50% reads, 50% read-modify-write

---

## 📊 Benchmarking

### Baseline Test

```bash
# Simple GET/SET test
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=50 \
  --threads=4 \
  --requests=100000 \
  --data-size=1024 \
  --key-pattern=R:R \
  --ratio=1:1 \
  --print-percentiles=50,95,99,99.9
```

**Expected Results (baseline):**
- **Throughput**: 50,000-100,000 OPS
- **Latency (p99)**: < 5ms
- **CPU Usage**: < 50%
- **Memory Usage**: < 80%

### Read-Heavy Workload

```bash
# 95% reads, 5% writes
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=100 \
  --threads=8 \
  --requests=100000 \
  --data-size=1024 \
  --key-pattern=R:R \
  --ratio=19:1 \
  --print-percentiles=50,95,99,99.9
```

### Write-Heavy Workload

```bash
# 20% reads, 80% writes
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=100 \
  --threads=8 \
  --requests=100000 \
  --data-size=1024 \
  --key-pattern=R:R \
  --ratio=1:4 \
  --print-percentiles=50,95,99,99.9
```

### Large Object Test

```bash
# Test with 10KB objects
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=50 \
  --threads=4 \
  --requests=50000 \
  --data-size=10240 \
  --key-pattern=R:R \
  --ratio=1:1 \
  --print-percentiles=50,95,99,99.9
```

---

## 🚀 Load Testing

### Sustained Load Test

```bash
# Run for 10 minutes
memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=100 \
  --threads=8 \
  --test-time=600 \
  --data-size=1024 \
  --key-pattern=R:R \
  --ratio=1:1 \
  --print-percentiles=50,95,99,99.9
```

### Spike Test

```bash
# Gradually increase load
for clients in 10 50 100 200 500; do
  echo "Testing with $clients clients..."
  memtier_benchmark \
    -s redis-db.redis-enterprise.svc.cluster.local \
    -p 12000 \
    --protocol=redis \
    --clients=$clients \
    --threads=4 \
    --requests=10000 \
    --data-size=1024 \
    --ratio=1:1
  sleep 10
done
```

---

## 📚 Related Documentation

- [Capacity Planning](../capacity-planning/README.md)
- [Monitoring](../../monitoring/README.md)
- [Troubleshooting](../troubleshooting/README.md)

---

## 🔗 References

- memtier_benchmark: https://github.com/RedisLabs/memtier_benchmark
- YCSB: https://github.com/brianfrankcooper/YCSB
- Redis Benchmarking: https://redis.io/docs/latest/operate/rs/references/cli-utilities/memtier-benchmark/

