# High Availability & Disaster Recovery for Redis Enterprise

Complete guide for HA and DR strategies for Redis Enterprise on Kubernetes.

## 📋 Table of Contents

- [Overview](#overview)
- [High Availability](#high-availability)
- [Disaster Recovery](#disaster-recovery)
- [RTO and RPO](#rto-and-rpo)
- [Implementation](#implementation)
- [Testing](#testing)
- [Best Practices](#best-practices)

---

## 🎯 Overview

**High Availability (HA):** Minimize downtime during failures  
**Disaster Recovery (DR):** Recover from catastrophic failures

**Key Metrics:**
- **RTO (Recovery Time Objective):** Maximum acceptable downtime
- **RPO (Recovery Point Objective):** Maximum acceptable data loss

---

## 🏗️ High Availability Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              High Availability Architecture                  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Kubernetes Cluster                       │  │
│  │                                                        │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐              │  │
│  │  │ Node 1  │  │ Node 2  │  │ Node 3  │              │  │
│  │  │ REC Pod │  │ REC Pod │  │ REC Pod │              │  │
│  │  │ (Master)│  │ (Replica│  │ (Replica│              │  │
│  │  └─────────┘  └─────────┘  └─────────┘              │  │
│  │                                                        │  │
│  │  Automatic Failover: < 30 seconds                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### HA Components

1. **Multi-Node Cluster** (minimum 3 nodes)
2. **Database Replication** (master-replica)
3. **Automatic Failover**
4. **Pod Anti-Affinity** (spread across nodes/zones)
5. **Persistent Storage** (replicated volumes)

---

## 🔄 Disaster Recovery Architecture

```
┌─────────────────────────────────────────────────────────────┐
│           Disaster Recovery Architecture                     │
│                                                              │
│  ┌──────────────────┐              ┌──────────────────┐    │
│  │  Primary Region  │              │  DR Region       │    │
│  │  (us-east-1)     │              │  (us-west-2)     │    │
│  │                  │              │                  │    │
│  │  ┌────────────┐  │              │  ┌────────────┐  │    │
│  │  │    REC     │  │              │  │    REC     │  │    │
│  │  │  (Active)  │  │              │  │ (Standby)  │  │    │
│  │  └────────────┘  │              │  └────────────┘  │    │
│  │        │          │              │        ▲         │    │
│  │        │          │              │        │         │    │
│  │        ▼          │              │        │         │    │
│  │  ┌────────────┐  │   Backup     │  ┌────────────┐  │    │
│  │  │   Backup   │──┼──────────────┼─▶│  Restore   │  │    │
│  │  │  (S3/GCS)  │  │              │  │  (S3/GCS)  │  │    │
│  │  └────────────┘  │              │  └────────────┘  │    │
│  └──────────────────┘              └──────────────────┘    │
│                                                              │
│  RTO: < 1 hour  |  RPO: < 15 minutes                       │
└─────────────────────────────────────────────────────────────┘
```

### DR Strategies

1. **Backup and Restore** (RPO: minutes to hours, RTO: hours)
2. **Active-Passive** (RPO: minutes, RTO: minutes)
3. **Active-Active** (RPO: near-zero, RTO: near-zero)

---

## 📊 RTO and RPO Targets

| Strategy | RTO | RPO | Cost | Complexity |
|----------|-----|-----|------|------------|
| **Backup/Restore** | 1-4 hours | 15 min - 1 hour | Low | Low |
| **Active-Passive** | 5-30 minutes | 1-15 minutes | Medium | Medium |
| **Active-Active** | < 1 minute | Near-zero | High | High |

---

## 📦 Implementation

### 1. High Availability Configuration

See: [01-ha-cluster.yaml](01-ha-cluster.yaml)

**Features:**
- 3+ node cluster
- Database replication
- Pod anti-affinity
- Persistent storage

```bash
kubectl apply -f 01-ha-cluster.yaml
```

### 2. Backup Configuration

See: [02-backup-schedule.yaml](02-backup-schedule.yaml)

**Features:**
- Automated backups (every 6 hours)
- Retention policy (30 days)
- S3/GCS/Azure storage

```bash
kubectl apply -f 02-backup-schedule.yaml
```

### 3. Active-Passive DR

See: [03-active-passive-dr.yaml](03-active-passive-dr.yaml)

**Features:**
- Primary cluster (active)
- DR cluster (standby)
- Automated backup replication

```bash
kubectl apply -f 03-active-passive-dr.yaml
```

### 4. Active-Active DR

See: [04-active-active-dr.yaml](04-active-active-dr.yaml)

**Features:**
- Multi-region deployment
- Bidirectional replication
- Conflict resolution

```bash
kubectl apply -f 04-active-active-dr.yaml
```

---

## 🧪 Testing

### Test HA Failover

```bash
# 1. Identify master pod
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status

# 2. Delete master pod
kubectl delete pod rec-0 -n redis-enterprise

# 3. Verify automatic failover (< 30 seconds)
kubectl exec -it rec-1 -n redis-enterprise -- rladmin status

# 4. Verify database is accessible
redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 PING
```

### Test DR Restore

```bash
# 1. Create test data in primary
redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 SET test-key "test-value"

# 2. Trigger backup
kubectl exec -it rec-0 -n redis-enterprise -- rladmin backup db db:1

# 3. Restore in DR cluster
kubectl apply -f restore-from-backup.yaml

# 4. Verify data in DR cluster
redis-cli -h redis-db-dr.redis-enterprise.svc.cluster.local -p 12000 GET test-key
```

### Test Active-Active Failover

```bash
# 1. Write to Region 1
redis-cli -h redis-db-region1.redis-enterprise.svc.cluster.local -p 12000 SET key1 "value1"

# 2. Verify replication to Region 2
redis-cli -h redis-db-region2.redis-enterprise.svc.cluster.local -p 12000 GET key1

# 3. Simulate Region 1 failure
kubectl delete namespace redis-enterprise --context=region1

# 4. Verify Region 2 is still accessible
redis-cli -h redis-db-region2.redis-enterprise.svc.cluster.local -p 12000 PING
```

---

## ✅ Best Practices

### 1. **Multi-Zone Deployment**
- ✅ Deploy across 3+ availability zones
- ✅ Use pod anti-affinity
- ✅ Use topology spread constraints

### 2. **Regular Backups**
- ✅ Automated backups every 6-12 hours
- ✅ Store in different region/cloud
- ✅ Test restore procedures regularly

### 3. **Monitoring and Alerting**
- ✅ Monitor cluster health
- ✅ Alert on failover events
- ✅ Track backup success/failure

### 4. **Disaster Recovery Drills**
- ✅ Test DR procedures quarterly
- ✅ Document runbooks
- ✅ Measure actual RTO/RPO

### 5. **Data Persistence**
- ✅ Enable AOF (Append-Only File)
- ✅ Use replicated storage
- ✅ Regular snapshot backups

---

## 📚 Related Documentation

- [Backup & Restore](../../backup-restore/README.md)
- [Active-Active Deployment](../../deployments/active-active/README.md)
- [Monitoring](../../observability/monitoring/README.md)

---

## 🔗 References

- Redis Enterprise HA: https://redis.io/docs/latest/operate/rs/databases/configure/high-availability/
- Kubernetes HA: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/

