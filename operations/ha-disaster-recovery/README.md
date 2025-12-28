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

1. **Multi-Node Cluster** (minimum 3 nodes/pods)
2. **Database Replication** (master-replica)
3. **Automatic Failover**
4. **Pod Anti-Affinity** (spread across nodes/zones - enabled by default)
5. **Persistent Storage** (replicated volumes - block storage only, NEVER NFS)
6. **Spare Node Strategy** (always have 1+ spare K8s node per AZ)
7. **PodDisruptionBudget** (maintains quorum during voluntary disruptions)
8. **PriorityClass** (prevents preemption by lower-priority workloads)

### 🔑 Critical HA Requirements

**✅ MUST HAVE:**
- **Minimum 3 REC pods** for quorum (ALWAYS)
- **One REC pod per Kubernetes node** (anti-affinity enforced by default)
- **Spare Kubernetes node in each AZ** to handle node failures
- **Block storage only** (EBS, Persistent Disk, Azure Disk) - NEVER NFS
- **Minimum pod resources:** 4000m CPU, 15GB memory
- **PodDisruptionBudget** to protect quorum during drains
- **Clock synchronization** (NTP) on all worker nodes

**❌ NEVER:**
- Scale REC StatefulSet to 0 (never stop all pods)
- Use 2-node clusters (no quorum)
- Use NFS for persistence
- Drain multiple nodes simultaneously (breaks quorum)
- Make changes to REC StatefulSet directly

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
- 3+ node cluster (minimum 3 REC pods)
- Database replication
- Pod anti-affinity (enabled by default - one REC pod per K8s node)
- Persistent storage (block storage only - NEVER NFS)
- PodDisruptionBudget to maintain quorum
- PriorityClass to prevent preemption

**Spare Node Strategy:**

For a 3-node REC cluster across 3 AZs, you need **minimum 4 Kubernetes worker nodes**:

```
AZ-1: 2 nodes (1 for REC pod, 1 spare)
AZ-2: 1 node (1 for REC pod)
AZ-3: 1 node (1 for REC pod)
```

**Why?** If a node in AZ-1 fails, the REC pod can be rescheduled to the spare node in AZ-1, maintaining the 3-pod quorum.

**Best Practice:** Have at least 1 spare node per AZ:

```
AZ-1: 2 nodes (1 REC pod + 1 spare)
AZ-2: 2 nodes (1 REC pod + 1 spare)
AZ-3: 2 nodes (1 REC pod + 1 spare)
Total: 6 nodes for 3-pod REC cluster
```

This ensures you can handle node failures in any AZ without losing quorum.

```bash
kubectl apply -f 01-ha-cluster.yaml
kubectl apply -f 05-pod-disruption-budget.yaml
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

