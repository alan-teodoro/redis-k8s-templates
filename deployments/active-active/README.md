# Active-Active Redis Enterprise Deployment

This directory contains YAML configurations for deploying Redis Enterprise Active-Active databases across two Kubernetes clusters.

## 📋 Overview

Active-Active deployment provides:
- **Geo-distributed databases** across multiple regions/clusters
- **Local read/write** in each region with low latency
- **Conflict-free replication** using CRDTs (Conflict-free Replicated Data Types)
- **Automatic conflict resolution** for concurrent writes
- **High availability** and disaster recovery

## 🏗️ Architecture

```
┌─────────────────────────────────┐      ┌─────────────────────────────────┐
│   Cluster A (Region 1)          │      │   Cluster B (Region 2)          │
│   Namespace: redis-enterprise   │      │   Namespace: redis-enterprise   │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Redis Enterprise Cluster │   │      │   │ Redis Enterprise Cluster │  │
│  │ Name: rec-a              │   │      │   │ Name: rec-b              │  │
│  │ Nodes: 3                 │   │      │   │ Nodes: 3                 │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Remote Cluster (rerc-a)  │◄──┼──────┼──►│ Remote Cluster (rerc-a)  │  │
│  │ Remote Cluster (rerc-b)  │◄──┼──────┼──►│ Remote Cluster (rerc-b)  │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  ┌──────────────────────────┐   │      │   ┌──────────────────────────┐  │
│  │ Active-Active Database   │   │      │   │ Active-Active Database   │  │
│  │ Name: aadb               │◄──┼──────┼──►│ Name: aadb               │  │
│  │ Port: 12000              │   │      │   │ Port: 12000              │  │
│  └──────────────────────────┘   │      │   └──────────────────────────┘  │
│                                 │      │                                 │
│  Application writes locally ────┼──────┼──── Application writes locally  │
│  Reads from local instance      │      │     Reads from local instance   │
└─────────────────────────────────┘      └─────────────────────────────────┘
           │                                            │
           └────────────── Bi-directional ─────────────┘
                        Replication (CRDT)
```

## 📁 Directory Structure

```
active-active/
├── README.md                          # This file
├── 08-remote-cluster-api-guide.md     # RERC detailed documentation
├── 09-rerc-advanced-examples.yaml     # Advanced RERC examples (multi-region, hybrid cloud)
├── cluster-a/                         # Cluster A configurations
│   ├── 00-namespace.yaml              # Namespace
│   ├── 01-rec-admin-secret.yaml       # Admin credentials
│   ├── 02-rbac-rack-awareness.yaml    # RBAC for rack awareness
│   ├── 03-rec.yaml                    # Redis Enterprise Cluster
│   ├── 04-rerc-secrets.yaml           # Remote cluster secrets
│   ├── 05-rerc.yaml                   # Remote cluster definitions (RERC)
│   ├── 06-reaadb-secret.yaml          # Database password
│   └── 07-reaadb.yaml                 # Active-Active database
└── cluster-b/                         # Cluster B configurations
    ├── 00-namespace.yaml
    ├── 01-rec-admin-secret.yaml
    ├── 02-rbac-rack-awareness.yaml
    ├── 03-rec.yaml
    ├── 04-rerc-secrets.yaml
    ├── 05-rerc.yaml                   # Remote cluster definitions (RERC)
    └── 06-reaadb-secret.yaml
```

**Note:** Database (REAADB) is created only on Cluster A and automatically replicates to Cluster B.

---

## 🚀 Quick Start

**TL;DR - Complete deployment in 5 steps:**

1. **Install NGINX Ingress** on both clusters
2. **Install Redis Operator** on both clusters
3. **Update FQDNs** in YAML files with Ingress IPs
4. **Deploy RECs** on both clusters
5. **Configure RERC** and create Active-Active database

**Estimated time:** 30-40 minutes

---

## 📝 Detailed Deployment Guide

### Prerequisites

1. **Two Kubernetes clusters** (GKE, EKS, AKS, or on-prem)
2. **kubectl** configured with contexts for both clusters
3. **Helm 3.x** installed
4. **Network connectivity** between clusters (ports 80, 443, 8443, 9443)
5. **LoadBalancer** support (for Ingress external IPs)

---

## 📝 Step-by-Step Deployment

### Step 0: Install Prerequisites (REQUIRED)

**⚠️ IMPORTANT: Install on BOTH clusters before proceeding!**

#### 0.1: Install NGINX Ingress Controller

**On Cluster A:**
```bash
# Set context to Cluster A
kubectl config use-context <cluster-a-context>

# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true

# Wait for LoadBalancer IP to be assigned
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get the Ingress LoadBalancer IP (SAVE THIS!)
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**On Cluster B:**
```bash
# Set context to Cluster B
kubectl config use-context <cluster-b-context>

# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.enable-ssl-passthrough=true

# Wait for LoadBalancer IP
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get the Ingress LoadBalancer IP (SAVE THIS!)
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**📝 Note the LoadBalancer IPs - you'll need them for the next step!**

---

#### 0.2: Install Redis Enterprise Operator

**On Cluster A:**
```bash
# Set context to Cluster A
kubectl config use-context <cluster-a-context>

# Add Redis Helm repository
helm repo add redis https://helm.redis.io
helm repo update

# Install Operator
helm install redis-operator redis/redis-enterprise-operator \
  --version 8.0.6-8 \
  -n redis-enterprise \
  --create-namespace

# Verify installation
kubectl get pods -n redis-enterprise
```

**On Cluster B:**
```bash
# Set context to Cluster B
kubectl config use-context <cluster-b-context>

# Add Redis Helm repository (if not already added)
helm repo add redis https://helm.redis.io
helm repo update

# Install Operator
helm install redis-operator redis/redis-enterprise-operator \
  --version 8.0.6-8 \
  -n redis-enterprise \
  --create-namespace

# Verify installation
kubectl get pods -n redis-enterprise
```

**Wait for Operator pods to be Running on both clusters before proceeding.**

---

### Step 1: Configure FQDNs with Ingress LoadBalancer IPs

**⚠️ IMPORTANT: Update FQDNs using the Ingress LoadBalancer IPs from Step 0.1**

Using the LoadBalancer IPs you saved from Step 0.1, update the configuration files.

**Example:** If your IPs are:
- Cluster A Ingress IP: `104.197.244.251`
- Cluster B Ingress IP: `34.59.153.207`

#### 1.1: Update Cluster A Configuration

Edit `cluster-a/03-rec.yaml`:
```yaml
spec:
  # ... other config ...
  ingressOrRouteSpec:
    apiFqdnUrl: rec-a-api.104.197.244.251.nip.io
    dbFqdnSuffix: .db-rec-a.104.197.244.251.nip.io
    method: ingress
    ingressAnnotations:
      kubernetes.io/ingress.class: "nginx"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

Edit `cluster-a/05-rerc.yaml`:
```yaml
# First RERC (local - Cluster A)
spec:
  recName: rec-a
  apiFqdnUrl: rec-a-api.104.197.244.251.nip.io
  dbFqdnSuffix: .db-rec-a.104.197.244.251.nip.io

---
# Second RERC (remote - Cluster B)
spec:
  recName: rec-b
  apiFqdnUrl: rec-b-api.34.59.153.207.nip.io
  dbFqdnSuffix: .db-rec-b.34.59.153.207.nip.io
```

#### 1.2: Update Cluster B Configuration

Edit `cluster-b/03-rec.yaml`:
```yaml
spec:
  # ... other config ...
  ingressOrRouteSpec:
    apiFqdnUrl: rec-b-api.34.59.153.207.nip.io
    dbFqdnSuffix: .db-rec-b.34.59.153.207.nip.io
    method: ingress
    ingressAnnotations:
      kubernetes.io/ingress.class: "nginx"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

Edit `cluster-b/05-rerc.yaml`:
```yaml
# First RERC (local - Cluster A)
spec:
  recName: rec-a
  apiFqdnUrl: rec-a-api.104.197.244.251.nip.io
  dbFqdnSuffix: .db-rec-a.104.197.244.251.nip.io

---
# Second RERC (remote - Cluster B)
spec:
  recName: rec-b
  apiFqdnUrl: rec-b-api.34.59.153.207.nip.io
  dbFqdnSuffix: .db-rec-b.34.59.153.207.nip.io
```

**💡 Note:** We're using `nip.io` which is a free DNS service that resolves `*.IP.nip.io` to the IP address. Perfect for demos and testing!

**For production:** Replace with your actual DNS records pointing to the Ingress IPs.

## 🔐 Default Credentials

**Pre-configured credentials for testing/demo purposes:**

| Component | Username | Password |
|-----------|----------|----------|
| **REC Admin** | `admin@redis.com` | `RedisAdmin123!` |
| **Database** | `default` | `RedisAdmin123!` |
| **Database Port** | - | `12000` |

**⚠️ SECURITY WARNING:** These are default credentials for testing/demo purposes only. **ALWAYS change passwords before production deployment!**

## 📝 Deployment Instructions

### Step 2: Deploy Redis Enterprise Clusters

**⚠️ Make sure you completed Step 1 (FQDN configuration) before proceeding!**

**📝 Note on Rack Awareness:**
- If your nodes have `topology.kubernetes.io/zone` labels, you can enable rack awareness by uncommenting the RBAC file and the `rackAwarenessNodeLabel` in `03-rec.yaml`
- To check: `kubectl get nodes --show-labels | grep topology.kubernetes.io/zone`
- If nodes don't have zone labels, skip the RBAC file and comment out `rackAwarenessNodeLabel` in the REC spec

**On Cluster A:**
```bash
# Set context to Cluster A
kubectl config use-context <cluster-a-context>

# Navigate to cluster-a directory
cd deployments/active-active/cluster-a/

# Deploy REC (skip RBAC if nodes don't have zone labels)
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-rec-admin-secret.yaml
# kubectl apply -f 02-rbac-rack-awareness.yaml  # Only if nodes have topology.kubernetes.io/zone labels
kubectl apply -f 03-rec.yaml

# Wait for cluster ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec-a -n redis-enterprise --timeout=600s

# Verify Ingress was created
kubectl get ingress -n redis-enterprise
```

**On Cluster B:**
```bash
# Set context to Cluster B
kubectl config use-context <cluster-b-context>

# Navigate to cluster-b directory
cd deployments/active-active/cluster-b/
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-rec-admin-secret.yaml
# kubectl apply -f 02-rbac-rack-awareness.yaml  # Only if nodes have topology.kubernetes.io/zone labels
kubectl apply -f 03-rec.yaml

# Wait for cluster ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec-b -n redis-enterprise --timeout=600s

# Verify Ingress was created
kubectl get ingress -n redis-enterprise
```

**✅ Verification:** Both clusters should have Ingress resources created automatically by the Operator.

```bash
# On Cluster A
kubectl get ingress -n redis-enterprise
# Should show: rec-a-api, rec-a-db-*

# On Cluster B
kubectl get ingress -n redis-enterprise
# Should show: rec-b-api, rec-b-db-*
```

---

### Step 3: Configure Remote Cluster Connections

**⚠️ Make sure Step 1 (FQDN configuration) was completed correctly!**

**On Cluster A:**
```bash
kubectl config use-context <cluster-a-context>
cd deployments/active-active/cluster-a/

kubectl apply -f 04-rerc-secrets.yaml
kubectl apply -f 05-rerc.yaml

# Verify remote clusters (should show 2 RERC: rerc-a and rerc-b)
kubectl get rerc -n redis-enterprise

# Check status (both should be "Active" after ~30 seconds)
kubectl get rerc -n redis-enterprise -o wide
```

**On Cluster B:**
```bash
kubectl config use-context <cluster-b-context>
cd deployments/active-active/cluster-b/

kubectl apply -f 04-rerc-secrets.yaml
kubectl apply -f 05-rerc.yaml

# Verify remote clusters (should show 2 RERC: rerc-a and rerc-b)
kubectl get rerc -n redis-enterprise

# Check status (both should be "Active" after ~30 seconds)
kubectl get rerc -n redis-enterprise -o wide
```

**✅ Expected Output:**
```
NAME     STATUS   SPEC STATUS   LOCAL
rerc-a   Active   Valid         true
rerc-b   Active   Valid         false
```

**🔍 Troubleshooting:** If RERC status is "Error", check:
```bash
kubectl describe rerc rerc-a -n redis-enterprise
kubectl describe rerc rerc-b -n redis-enterprise
```

Common issues:
- FQDNs not updated correctly in Step 1
- Ingress not created (check `kubectl get ingress -n redis-enterprise`)
- Network connectivity between clusters

---

### Step 4: Create Active-Active Database

**⚠️ Only create the database on Cluster A - it will automatically replicate to Cluster B!**

**On Cluster A only:**
```bash
kubectl config use-context <cluster-a-context>
cd deployments/active-active/cluster-a/

kubectl apply -f 06-reaadb-secret.yaml
kubectl apply -f 07-reaadb.yaml

# Wait for database creation (2-5 minutes)
kubectl wait --for=condition=Active reaadb/aadb -n redis-enterprise --timeout=300s

# Check database status
kubectl get reaadb -n redis-enterprise
```

**✅ Expected Output:**
```
NAME   STATUS   SPEC STATUS   LINKED REDBS
aadb   active   Valid         rec-a,rec-b
```

**Verify on Cluster B (database should appear automatically):**
```bash
kubectl config use-context <cluster-b-context>

# Check if database instance exists
kubectl get redb -n redis-enterprise

# Should show: aadb (created automatically via replication)
```

---

### Step 5: Verify Deployment

**Check all resources on both clusters:**

```bash
# Cluster A
kubectl config use-context <cluster-a-context>

# Check REC status
kubectl get rec -n redis-enterprise
# Expected: rec-a with STATUS=Running

# Check RERC status
kubectl get rerc -n redis-enterprise
# Expected: rerc-a (local) and rerc-b (remote) both Active

# Check REAADB status
kubectl get reaadb -n redis-enterprise
# Expected: aadb with STATUS=active

# Check Ingress
kubectl get ingress -n redis-enterprise
# Expected: rec-a-api and database ingresses

# Cluster B
kubectl config use-context <cluster-b-context>

# Check REC status
kubectl get rec -n redis-enterprise
# Expected: rec-b with STATUS=Running

# Check RERC status
kubectl get rerc -n redis-enterprise
# Expected: rerc-a (remote) and rerc-b (local) both Active

# Check REDB (database instance)
kubectl get redb -n redis-enterprise
# Expected: aadb (replicated from Cluster A)

# Check Ingress
kubectl get ingress -n redis-enterprise
# Expected: rec-b-api and database ingresses
```

---

## 🔍 Testing Active-Active Replication

### Test 1: Write to Cluster A, Read from Cluster B

**On Cluster A:**
```bash
kubectl config use-context <cluster-a-context>

# Write data
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -n redis-enterprise -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  SET test-key "written-from-cluster-a"
```

**On Cluster B:**
```bash
kubectl config use-context <cluster-b-context>

# Read data (should see the value from Cluster A)
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -n redis-enterprise -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  GET test-key
```

**✅ Expected:** Should return `"written-from-cluster-a"` (replicated within seconds)

---

### Test 2: Bi-directional Replication

**On Cluster B:**
```bash
# Write from Cluster B
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -n redis-enterprise -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  SET another-key "written-from-cluster-b"
```

**On Cluster A:**
```bash
# Read from Cluster A
kubectl run -it --rm redis-test --image=redis:latest --restart=Never -n redis-enterprise -- \
  redis-cli -h aadb.redis-enterprise.svc.cluster.local \
  -p 12000 --tls --insecure -a RedisAdmin123! \
  GET another-key
```

**✅ Expected:** Should return `"written-from-cluster-b"` (bi-directional replication works!)

---

### Test 3: Check Replication Status via UI

**Access Redis Enterprise UI:**

```bash
# Get UI LoadBalancer IP for Cluster A
kubectl get svc rec-a-ui -n redis-enterprise -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Access: https://<IP>:8443
# Username: admin@redis.com
# Password: RedisAdmin123!
```

**In the UI:**
1. Navigate to **Databases** → **aadb**
2. Click **Configuration** tab → **Replication**
3. Verify both instances show **"Synced"** status
4. Check **Replication lag** (should be < 1 second)

---

## 🔧 Configuration Details

### Redis Enterprise Cluster (REC)

- **Nodes:** 3 per cluster (for high availability)
- **CPU:** 2 cores per node
- **Memory:** 4Gi per node
- **Storage:** 10Gi per node
- **Rack Awareness:** Enabled (distributes across availability zones)

### Active-Active Database (REAADB)

- **Name:** aadb
- **Type:** Redis with CRDT
- **Memory:** 200MB (total across all instances)
- **Port:** 12000 (fixed for consistency)
- **Shards:** 1
- **Replication:** Enabled (master + replica per cluster)
- **TLS:** Enabled
- **Password:** From secret `reaadb-secret`

### Supported Modules

Not all Redis modules support Active-Active. Compatible modules include:
- **RedisJSON** (rejson)
- **RedisBloom** (bf)
- **RedisTimeSeries** (timeseries)

**Note:** Check [Redis Active-Active documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/develop/) for module compatibility.

---

## 🔍 Troubleshooting

### Remote Cluster Connection Issues

```bash
# Check RERC status
kubectl get rerc -n redis-enterprise
kubectl describe rerc rerc-b -n redis-enterprise

# Verify network connectivity from REC pod
kubectl exec -it rec-a-0 -n redis-enterprise -- \
  curl -k https://<cluster-b-api-fqdn>:9443
```

### Database Not Replicating

```bash
# Check database status
kubectl describe reaadb aadb -n redis-enterprise

# Check logs
kubectl logs -n redis-enterprise rec-a-0 | grep -i replication

# Verify participating clusters
kubectl get reaadb aadb -n redis-enterprise -o yaml | grep -A 5 participatingClusters
```

### TLS Certificate Issues

1. Access UI on both clusters
2. Navigate to **Cluster** → **Security** → **Certificates**
3. Download and compare certificates
4. Ensure certificates are valid and trusted

---

## 🧹 Cleanup

```bash
# Cluster A
kubectl config use-context <cluster-a-context>
kubectl delete -f cluster-a/07-reaadb.yaml
kubectl delete -f cluster-a/06-reaadb-secret.yaml
kubectl delete -f cluster-a/05-rerc.yaml
kubectl delete -f cluster-a/04-rerc-secrets.yaml
kubectl delete -f cluster-a/03-rec.yaml
# kubectl delete -f cluster-a/02-rbac-rack-awareness.yaml  # If you applied it
kubectl delete -f cluster-a/01-rec-admin-secret.yaml
kubectl delete -f cluster-a/00-namespace.yaml

# Cluster B
kubectl config use-context <cluster-b-context>
kubectl delete -f cluster-b/05-rerc.yaml
kubectl delete -f cluster-b/04-rerc-secrets.yaml
kubectl delete -f cluster-b/03-rec.yaml
# kubectl delete -f cluster-b/02-rbac-rack-awareness.yaml  # If you applied it
kubectl delete -f cluster-b/01-rec-admin-secret.yaml
kubectl delete -f cluster-b/00-namespace.yaml

# Delete Operators (optional)
kubectl config use-context <cluster-a-context>
helm uninstall redis-operator -n redis-enterprise
helm uninstall ingress-nginx -n ingress-nginx

kubectl config use-context <cluster-b-context>
helm uninstall redis-operator -n redis-enterprise
helm uninstall ingress-nginx -n ingress-nginx

# Delete namespaces (this will delete everything)
kubectl config use-context <cluster-a-context>
kubectl delete namespace redis-enterprise
kubectl delete namespace ingress-nginx

kubectl config use-context <cluster-b-context>
kubectl delete namespace redis-enterprise
kubectl delete namespace ingress-nginx
```

---

## 🔗 Remote Cluster API (RERC)

### O que é RERC?

**RedisEnterpriseRemoteCluster (RERC)** é o Custom Resource que define a conexão entre clusters Redis Enterprise para Active-Active replication.

### Documentação Detalhada

Para informações completas sobre RERC, incluindo:
- Arquitetura e fluxo de comunicação
- Configurações avançadas
- Casos de uso (multi-region, hybrid cloud, etc.)
- Troubleshooting

Veja: **[08-remote-cluster-api-guide.md](./08-remote-cluster-api-guide.md)**

### Exemplos Avançados

Para exemplos de configurações avançadas:
- Multi-Region (3+ regiões)
- Hybrid Cloud (AWS + Azure + GCP)
- Multi-Cluster HA

Veja: **[09-rerc-advanced-examples.yaml](./09-rerc-advanced-examples.yaml)**

---

## 📚 Additional Resources

- [Active-Active Geo-Distribution](https://redis.io/docs/latest/operate/rs/databases/active-active/)
- [CRDT Documentation](https://redis.io/docs/latest/operate/rs/databases/active-active/develop/)
- [RERC API Reference](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/redis-enterprise-remote-cluster/)
- [Network Requirements](https://redis.io/docs/latest/operate/rs/networking/port-configurations/)
- [Networking Configuration](../networking/README.md)


