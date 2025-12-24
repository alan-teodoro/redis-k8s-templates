# Redis Load Testing with Memtier Benchmark

This directory contains tools and configurations for load testing Redis Enterprise databases using memtier_benchmark.

## Overview

Memtier benchmark is a high-throughput benchmarking tool for Redis and Memcached, developed by Redis Ltd. It's useful for:
- Performance testing and validation
- Capacity planning
- Comparing different configurations
- Stress testing before production

## Quick Start

### 1. Deploy Memtier Pod

**⚠️ Before deploying:** Update the Redis certificate in `memtier-benchmark.yaml` with the certificate from your cluster:

1. Access your Redis Enterprise UI
2. Navigate to **Cluster** → **Security** → **Certificates**
3. Copy the **Proxy certificate** content
4. Replace the certificate in the `redis-cert` Secret in `memtier-benchmark.yaml`

```bash
# Deploy the memtier benchmark pod
oc apply -f testing/memtier-benchmark.yaml

# Verify pod is running
oc get pod memtier-shell -n redis-ns-a
```

### 2. Get Database Connection Details

```bash
# Get database service name
oc get svc -n redis-ns-a | grep redb

# Get database route (for external access)
oc get route route-db -n redis-ns-a -o jsonpath='{.spec.host}'

# Get database password
oc get secret redb-secret -n redis-ns-a -o jsonpath='{.data.password}' | base64 -d
```

### 3. Run Benchmark

#### For TLS-Enabled Databases (Recommended for Production)

**Using Internal Service (from within cluster):**
```bash
oc exec -it memtier-shell -n redis-ns-a -- memtier_benchmark \
  -s <db-service-dns> \
  -p <port> \
  -a <password> \
  --tls \
  --tls-skip-verify \
  --sni <db-service-dns> \
  --ratio=1:4 \
  --test-time=600 \
  --pipeline=2 \
  --clients=2 \
  --threads=2 \
  --hide-histogram
```

**Example with internal service:**
```bash
oc exec -it memtier-shell -n redis-ns-a -- memtier_benchmark \
  -s redb.redis-ns-a.svc.cluster.local \
  -p 12000 \
  -a RedisAdmin123! \
  --tls \
  --tls-skip-verify \
  --sni redb.redis-ns-a.svc.cluster.local \
  --ratio=1:4 \
  --test-time=600 \
  --pipeline=2 \
  --clients=2 \
  --threads=2 \
  --hide-histogram
```

**Using External Route with CA Certificate:**

If you're testing via OpenShift route and have the CA certificate mounted (as configured in `memtier-benchmark.yaml`):

```bash
oc exec -it memtier-shell -n redis-ns-a -- memtier_benchmark \
  -s route-db-redis-ns-a.apps.cluster-lwrtg.dynamic.redhatworkshops.io \
  -p 443 \
  --tls \
  --sni route-db-redis-ns-a.apps.cluster-lwrtg.dynamic.redhatworkshops.io \
  --cacert /etc/redis-certs/redis.pem \
  -a 'default:RedisAdmin123!' \
  --ratio=1:4 \
  --test-time=60 \
  --pipeline=24 \
  --clients=4 \
  --threads=2 \
  --hide-histogram
```

**⚠️ Important:** Replace `route-db-redis-ns-a.apps.cluster-lwrtg.dynamic.redhatworkshops.io` with your actual database route hostname. Get it with:
```bash
oc get route route-db -n redis-ns-a -o jsonpath='{.spec.host}'
```

#### For Non-TLS Databases (Development/Testing)

```bash
oc exec -it memtier-shell -n redis-ns-a -- memtier_benchmark \
  -s <db-service-dns> \
  -p <port> \
  -a <password> \
  --ratio=1:4 \
  --test-time=600 \
  --pipeline=2 \
  --clients=2 \
  --threads=4 \
  --hide-histogram
```

## Benchmark Parameters Explained

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| `-s` | Server hostname/IP | Database service DNS |
| `-p` | Port number | Database port (e.g., 12000) |
| `-a` | Authentication password | Database password |
| `--tls` | Enable TLS | Use for production |
| `--tls-skip-verify` | Skip certificate verification | Use for self-signed certs |
| `--sni` | Server Name Indication | Required for Redis Enterprise |
| `--ratio` | SET:GET ratio | `1:4` (20% writes, 80% reads) |
| `--test-time` | Test duration in seconds | `600` (10 minutes) |
| `--pipeline` | Pipeline depth | `2-10` (higher = more throughput) |
| `--clients` | Clients per thread | `2-10` |
| `--threads` | Number of threads | `2-4` (match CPU cores) |
| `--hide-histogram` | Hide latency histogram | Cleaner output |

## Common Test Scenarios

### 1. Baseline Performance Test
```bash
# Balanced read/write workload
memtier_benchmark -s <host> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <host> \
  --ratio=1:1 --test-time=300 --clients=5 --threads=2
```

### 2. Read-Heavy Workload (Typical Web Application)
```bash
# 90% reads, 10% writes
memtier_benchmark -s <host> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <host> \
  --ratio=1:9 --test-time=600 --clients=10 --threads=4
```

### 3. Write-Heavy Workload
```bash
# 70% writes, 30% reads
memtier_benchmark -s <host> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <host> \
  --ratio=7:3 --test-time=600 --clients=5 --threads=2
```

### 4. Maximum Throughput Test
```bash
# High concurrency with pipelining
memtier_benchmark -s <host> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <host> \
  --ratio=1:4 --test-time=300 --pipeline=10 \
  --clients=20 --threads=4
```

### 5. Latency Test (Low Concurrency)
```bash
# Measure baseline latency without contention
memtier_benchmark -s <host> -p <port> -a <password> \
  --tls --tls-skip-verify --sni <host> \
  --ratio=1:4 --test-time=300 --pipeline=1 \
  --clients=1 --threads=1
```

## Understanding Results

Memtier outputs several key metrics:

```
Totals
Type         Ops/sec     Hits/sec   Misses/sec    Avg. Latency     p50 Latency     p99 Latency
------------------------------------------------------------------------
Sets        12345.67          ---          ---         1.23456         1.20000         2.50000
Gets        49382.68     49382.68         0.00         1.23456         1.20000         2.50000
Waits           0.00          ---          ---             ---             ---             ---
Totals      61728.35     49382.68         0.00         1.23456         1.20000         2.50000
```

**Key Metrics:**
- **Ops/sec**: Operations per second (throughput)
- **Avg. Latency**: Average latency in milliseconds
- **p50/p99 Latency**: 50th and 99th percentile latencies
- **Hits/Misses**: Cache hit/miss ratio (for GET operations)

## Best Practices

1. **Start Small**: Begin with low concurrency and gradually increase
2. **Monitor Resources**: Watch CPU, memory, and network during tests
3. **Multiple Runs**: Run tests multiple times and average results
4. **Realistic Workloads**: Match test patterns to your application
5. **Warm-up Period**: Run a short test first to warm up the database
6. **Document Results**: Save results for comparison and capacity planning

## Cleanup

```bash
# Delete the memtier pod when done
oc delete pod memtier-shell -n redis-ns-a
```

## Additional Resources

- [Memtier Benchmark Documentation](https://github.com/RedisLabs/memtier_benchmark)
- [Redis Benchmarking Guide](https://redis.io/docs/management/optimization/benchmarks/)
- [Redis Enterprise Performance Tuning](https://redis.io/docs/latest/operate/rs/databases/configure/performance/)

