# Migration & Upgrade Guide for Redis Enterprise on Kubernetes

Complete guide for upgrading Redis Enterprise and migrating data.

## 📋 Table of Contents

- [Operator Upgrade](#operator-upgrade)
- [Cluster Upgrade](#cluster-upgrade)
- [Database Migration](#database-migration)
- [Zero-Downtime Upgrade](#zero-downtime-upgrade)
- [Rollback Procedures](#rollback-procedures)

---

## 🔄 Operator Upgrade

### Prerequisites

```bash
# Check current operator version
kubectl get deployment redis-enterprise-operator -n redis-enterprise \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check available versions
# https://github.com/RedisLabs/redis-enterprise-k8s-docs/releases
```

### Upgrade Procedure

```bash
# 1. Backup current configuration
kubectl get rec -n redis-enterprise -o yaml > rec-backup.yaml
kubectl get redb -n redis-enterprise -o yaml > redb-backup.yaml

# 2. Update operator
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/v7.8.2-2/bundle.yaml

# 3. Verify operator upgrade
kubectl rollout status deployment/redis-enterprise-operator -n redis-enterprise

# 4. Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50
```

---

## 🔧 Cluster Upgrade

### Rolling Upgrade (Zero-Downtime)

```bash
# 1. Check current cluster version
kubectl get rec rec -n redis-enterprise -o jsonpath='{.spec.redisEnterpriseImageSpec}'

# 2. Update cluster version
kubectl patch rec rec -n redis-enterprise --type='json' \
  -p='[{"op": "replace", "path": "/spec/redisEnterpriseImageSpec", "value": "redislabs/redis:7.8.2-129"}]'

# 3. Monitor upgrade progress
kubectl get rec rec -n redis-enterprise -w

# 4. Check pod rollout
kubectl get pods -n redis-enterprise -w

# 5. Verify all nodes upgraded
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status nodes
```

**Upgrade Process:**
1. Operator upgrades one node at a time
2. Waits for node to be healthy
3. Moves to next node
4. Databases remain available throughout

**Expected Duration:** 5-10 minutes per node

---

## 📦 Database Migration

### Migrate from Standalone Redis to Redis Enterprise

#### Option 1: Using RIOT (Redis Input/Output Tool)

```bash
# Install RIOT
wget https://github.com/redis-developer/riot/releases/download/v3.1.4/riot-redis-3.1.4.zip
unzip riot-redis-3.1.4.zip
cd riot-redis-3.1.4/bin

# Migrate data
./riot-redis -h source-redis.example.com -p 6379 \
  replicate -h redis-db.redis-enterprise.svc.cluster.local -p 12000
```

#### Option 2: Using redis-cli with RDB

```bash
# 1. Create RDB backup from source
redis-cli -h source-redis.example.com BGSAVE

# 2. Copy RDB file
scp user@source:/var/lib/redis/dump.rdb ./

# 3. Restore to Redis Enterprise
kubectl cp dump.rdb redis-enterprise/rec-0:/tmp/dump.rdb

kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin restore database db:1 file /tmp/dump.rdb
```

#### Option 3: Using Replication

```bash
# 1. Configure source as replica source
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin database update db:1 \
  replica-of source-redis.example.com:6379

# 2. Wait for sync to complete
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin status databases extra replica_sync

# 3. Stop replication (promote to master)
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin database update db:1 replica-of no one

# 4. Update application to use new endpoint
```

---

## 🚀 Zero-Downtime Upgrade

### Strategy: Blue-Green Deployment

```bash
# 1. Deploy new cluster (green)
kubectl apply -f rec-new.yaml

# 2. Create database on new cluster
kubectl apply -f redb-new.yaml

# 3. Replicate data from old to new
kubectl exec -it rec-new-0 -n redis-enterprise -- \
  rladmin database update db:1 \
  replica-of redis-db-old.redis-enterprise.svc.cluster.local:12000

# 4. Wait for sync
kubectl exec -it rec-new-0 -n redis-enterprise -- \
  rladmin status databases extra replica_sync

# 5. Update application to use new endpoint
# (Update DNS, ConfigMap, or Service)

# 6. Stop replication
kubectl exec -it rec-new-0 -n redis-enterprise -- \
  rladmin database update db:1 replica-of no one

# 7. Decommission old cluster
kubectl delete rec rec-old -n redis-enterprise
```

---

## ⏮️ Rollback Procedures

### Rollback Operator

```bash
# 1. Revert to previous operator version
kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/v7.4.6-2/bundle.yaml

# 2. Verify rollback
kubectl rollout status deployment/redis-enterprise-operator -n redis-enterprise
```

### Rollback Cluster

```bash
# 1. Restore from backup
kubectl apply -f rec-backup.yaml

# 2. Wait for cluster to stabilize
kubectl get rec rec -n redis-enterprise -w

# 3. Verify cluster health
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status
```

### Rollback Database

```bash
# 1. Restore from backup
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin restore database db:1 \
  s3_bucket_name redis-backups \
  s3_backup_file <backup-before-upgrade>

# 2. Verify data
redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 DBSIZE
```

---

## ✅ Pre-Upgrade Checklist

- [ ] Review release notes for breaking changes
- [ ] Backup all databases
- [ ] Test upgrade in non-production environment
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Verify monitoring and alerting
- [ ] Document rollback procedure
- [ ] Ensure sufficient resources

---

## ✅ Post-Upgrade Checklist

- [ ] Verify all pods are running
- [ ] Check cluster status
- [ ] Verify database connectivity
- [ ] Run smoke tests
- [ ] Check monitoring dashboards
- [ ] Review logs for errors
- [ ] Update documentation
- [ ] Notify stakeholders of completion

---

## 📚 Related Documentation

- [HA & Disaster Recovery](../ha-disaster-recovery/README.md)
- [Backup & Restore](../../backup-restore/README.md)
- [Troubleshooting](../troubleshooting/README.md)

---

## 🔗 References

- Redis Enterprise Upgrade Guide: https://redis.io/docs/latest/operate/rs/installing-upgrading/upgrading/
- Operator Releases: https://github.com/RedisLabs/redis-enterprise-k8s-docs/releases
- RIOT Tool: https://github.com/redis-developer/riot

