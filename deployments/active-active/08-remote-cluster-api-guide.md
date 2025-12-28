# Remote Cluster API (RERC) - Complete Guide

Detailed documentation about RedisEnterpriseRemoteCluster (RERC) for Active-Active deployments.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### What is RERC?

**RedisEnterpriseRemoteCluster (RERC)** is a Custom Resource Definition (CRD) that defines the **connection between Redis Enterprise clusters** for Active-Active replication.

### Why use RERC?

✅ **Active-Active Replication**: Enables bidirectional replication between clusters  
✅ **Geo-Distribution**: Connects clusters in different regions/clouds  
✅ **Disaster Recovery**: Automatic failover between regions  
✅ **Low Latency**: Applications read/write locally  
✅ **Conflict Resolution**: CRDT resolves conflicts automatically  

### Components

| Component | Description |
|-----------|-------------|
| **RERC** | Defines connection to remote cluster |
| **REC** | Local Redis Enterprise Cluster |
| **REAADB** | Active-Active database that uses RERC |
| **Secret** | Credentials for authentication between clusters |

---

## 🏗️ Architecture

### Communication Flow

\`\`\`
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
\`\`\`

### Required Endpoints

For Active-Active to work, the following endpoints must be accessible:

| Endpoint | Port | Protocol | Usage |
|----------|------|----------|-------|
| **API FQDN** | 9443 | HTTPS | Cluster management |
| **DB FQDN** | 12000+ | TCP/TLS | Data replication |

---

## ⚙️ Configuration

### 1. Basic RERC Structure

\`\`\`yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: rerc-remote
  namespace: redis-enterprise
spec:
  # Remote REC name
  recName: rec-remote
  
  # Remote REC namespace
  recNamespace: redis-enterprise
  
  # Remote cluster API endpoint
  apiFqdnUrl: api-rec-remote.redis.example.com
  
  # Database suffix for remote cluster
  dbFqdnSuffix: .db-rec-remote.redis.example.com
  
  # Secret with remote cluster credentials
  secretName: redis-enterprise-rerc-remote
\`\`\`

### 2. Secret for RERC

The secret must contain the admin credentials of the remote cluster:

\`\`\`yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-enterprise-rerc-remote
  namespace: redis-enterprise
type: Opaque
stringData:
  username: admin@redis.com
  password: RedisAdmin123!
\`\`\`

### 3. Using RERC in REAADB

\`\`\`yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseActiveActiveDatabase
metadata:
  name: aadb
  namespace: redis-enterprise
spec:
  participatingClusters:
    # Local cluster
    - name: rerc-local
    
    # Remote cluster (defined via RERC)
    - name: rerc-remote
  
  globalConfigurations:
    memorySize: 2GB
    replication: true
\`\`\`

---

## 🎯 Use Cases

### 1. Active-Active between 2 Regions

**Scenario**: E-commerce with users in US-East and EU-West.

**Configuration**:
\`\`\`yaml
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
\`\`\`

### 2. Active-Active between 3+ Regions

**Scenario**: Global application with users in US, EU, APAC.

**Configuration**:
\`\`\`yaml
# REAADB with 3 clusters
spec:
  participatingClusters:
    - name: rerc-us-east
    - name: rerc-eu-west
    - name: rerc-apac-south
\`\`\`

### 3. Hybrid Cloud (AWS + Azure + GCP)

**Scenario**: Multi-cloud deployment to avoid vendor lock-in.

**Configuration**:
\`\`\`yaml
# Cluster AWS
- name: rerc-aws-us-east-1
  apiFqdnUrl: api-aws.redis.example.com

# Cluster Azure
- name: rerc-azure-eastus
  apiFqdnUrl: api-azure.redis.example.com

# Cluster GCP
- name: rerc-gcp-us-central1
  apiFqdnUrl: api-gcp.redis.example.com
\`\`\`

---

## 🔍 Troubleshooting

### 1. RERC cannot connect to remote cluster

**Symptom**:
\`\`\`bash
kubectl describe rerc rerc-b -n redis-enterprise
# Status: Error
# Message: Failed to connect to remote cluster
\`\`\`

**Check**:
\`\`\`bash
# Test connectivity to API endpoint
curl -k https://api-rec-b.redis.example.com:9443/v1/cluster

# Verify secret
kubectl get secret redis-enterprise-rerc-b -n redis-enterprise -o yaml
\`\`\`

**Solutions**:
- Check firewall/security groups (port 9443)
- Verify DNS resolution of FQDN
- Verify credentials in secret

### 2. Replication not working

**Symptom**: Data written in Cluster A does not appear in Cluster B.

**Check**:
\`\`\`bash
# REAADB status
kubectl describe reaadb aadb -n redis-enterprise

# Operator logs
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
\`\`\`

**Solutions**:
- Check connectivity on database port (12000+)
- Verify \`dbFqdnSuffix\` is correct
- Verify firewall allows traffic between clusters

### 3. REAADB stuck in "Pending"

**Symptom**:
\`\`\`bash
kubectl get reaadb -n redis-enterprise
# NAME   STATUS    AGE
# aadb   Pending   5m
\`\`\`

**Check**:
\`\`\`bash
# Verify all RERC are ready
kubectl get rerc -n redis-enterprise

# Check events
kubectl describe reaadb aadb -n redis-enterprise
\`\`\`

**Solutions**:
- Ensure all RERC are in "Active" state
- Verify REC has sufficient resources
- Check operator logs

---

## 📚 References

- [Active-Active Documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [RERC API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/redis-enterprise-remote-cluster/)
- [REAADB API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/redis-enterprise-active-active-database/)

