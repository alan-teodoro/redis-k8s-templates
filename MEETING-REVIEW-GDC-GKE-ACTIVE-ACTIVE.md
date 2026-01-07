# 📋 Reunião de Revisão - GDC/GKE + Active-Active

**Data:** 2026-01-07  
**Tópicos:** Google Distributed Cloud (GDC), GKE, Active-Active Replication

---

## 🎯 Objetivo da Reunião

Revisar implementações de Redis Enterprise em:
1. **GDC (Google Distributed Cloud)** - Bare metal on-premises
2. **GKE (Google Kubernetes Engine)** - Cloud managed
3. **Active-Active Replication** - Multi-cluster/multi-region

---

## 📂 Estrutura do Repositório

```
redis-k8s-templates/
├── gdc/                          # Google Distributed Cloud (bare metal)
├── gke/                          # Google Kubernetes Engine (cloud)
├── active-active/                # Active-Active replication
└── security/tls-certificates/    # TLS/cert-manager
```

---

## 1️⃣ GDC (Google Distributed Cloud)

### **O que é:**
- Kubernetes on-premises (bare metal)
- Antd (Anthos on bare metal)
- Para ambientes air-gapped ou edge

### **Arquivos:**
```
gdc/
├── README.md                     # Guia completo
├── 01-namespace.yaml             # Namespace redis-enterprise
├── 02-operator.yaml              # Redis Enterprise Operator
├── 03-rec.yaml                   # Redis Enterprise Cluster
└── 04-database.yaml              # Database example
```

### **Características Principais:**

| Item | Configuração | Motivo |
|------|--------------|--------|
| **Storage** | Local PV ou Rook/Ceph | Bare metal não tem cloud storage |
| **LoadBalancer** | MetalLB | Bare metal precisa de LB próprio |
| **Ingress** | NGINX Ingress | Acesso externo |
| **Resources** | CPU/Memory ajustáveis | Hardware dedicado |

### **Pontos de Atenção:**
- ⚠️ Storage class precisa existir antes
- ⚠️ MetalLB precisa de IP pool configurado
- ⚠️ Nodes precisam ter labels para affinity
- ⚠️ Verificar kernel parameters (vm.overcommit_memory)

### **Comandos de Validação:**
```bash
# Verificar storage class
kubectl get storageclass

# Verificar MetalLB
kubectl get configmap -n metallb-system

# Verificar REC
kubectl get rec -n redis-enterprise

# Verificar recursos
kubectl top nodes
```

---

## 2️⃣ GKE (Google Kubernetes Engine)

### **O que é:**
- Kubernetes gerenciado no Google Cloud
- Integração nativa com GCP
- Auto-scaling, auto-upgrade

### **Arquivos:**
```
gke/
├── README.md                     # Guia completo
├── 01-namespace.yaml             # Namespace redis-enterprise
├── 02-operator.yaml              # Redis Enterprise Operator
├── 03-rec.yaml                   # Redis Enterprise Cluster
├── 04-database.yaml              # Database example
└── terraform/                    # IaC para GKE cluster
```

### **Características Principais:**

| Item | Configuração | Motivo |
|------|--------------|--------|
| **Storage** | pd-ssd ou pd-balanced | Persistent Disk do GCP |
| **LoadBalancer** | type: LoadBalancer | GCP provisiona automaticamente |
| **Node Pool** | n2-standard-4+ | Recomendado para Redis |
| **Zones** | Multi-zone | Alta disponibilidade |

### **Pontos de Atenção:**
- ⚠️ Custo de Persistent Disk (pd-ssd é caro)
- ⚠️ LoadBalancer cria IP externo (custo)
- ⚠️ Node pool precisa ter recursos suficientes
- ⚠️ Verificar quotas do GCP

### **Comandos de Validação:**
```bash
# Verificar cluster GKE
gcloud container clusters list

# Verificar nodes
kubectl get nodes -o wide

# Verificar PVs
kubectl get pv

# Verificar LoadBalancer IPs
kubectl get svc -n redis-enterprise
```

---

## 3️⃣ Active-Active Replication

### **O que é:**
- Replicação bidirecional entre clusters
- Multi-region, multi-cloud
- Conflict resolution automático (CRDT)

### **Arquivos:**
```
active-active/
├── README.md                     # Guia completo
├── 01-cluster-a.yaml             # Cluster A (região 1)
├── 02-cluster-b.yaml             # Cluster B (região 2)
├── 03-active-active-db.yaml      # Database Active-Active
└── 04-test-replication.sh        # Script de teste
```

### **Características Principais:**

| Item | Configuração | Motivo |
|------|--------------|--------|
| **Clusters** | Mínimo 2 RECs | Replicação bidirecional |
| **Networking** | Conectividade entre clusters | Replicação via WAN |
| **Database** | CRDT enabled | Conflict resolution |
| **Certificates** | TLS para syncer | Segurança na replicação |

### **Topologias Suportadas:**

**1. Multi-Region (mesmo cloud):**
```
GKE us-central1  ←→  GKE us-east1
```

**2. Multi-Cloud:**
```
GKE (Google)  ←→  EKS (AWS)  ←→  AKS (Azure)
```

**3. Hybrid (cloud + on-prem):**
```
GKE (cloud)  ←→  GDC (on-prem)
```

### **Pontos de Atenção:**
- ⚠️ Latência entre clusters (< 100ms recomendado)
- ⚠️ Bandwidth suficiente para replicação
- ⚠️ Firewall rules entre clusters
- ⚠️ Certificados TLS para syncer
- ⚠️ Conflict resolution strategy (LWW, Counter, etc)

### **Comandos de Validação:**
```bash
# Verificar RECs em ambos clusters
kubectl get rec -n redis-enterprise --context=cluster-a
kubectl get rec -n redis-enterprise --context=cluster-b

# Verificar database Active-Active
kubectl get redb -n redis-enterprise

# Verificar replicação
kubectl exec -it <pod> -- rladmin status
```

---

## 🔍 Checklist de Revisão

### **GDC:**
- [ ] Storage class configurado
- [ ] MetalLB instalado e configurado
- [ ] Nodes com recursos suficientes
- [ ] REC rodando (3 nodes)
- [ ] Database criado e acessível
- [ ] Ingress configurado

### **GKE:**
- [ ] Cluster GKE criado (multi-zone)
- [ ] Node pool adequado (n2-standard-4+)
- [ ] Storage class (pd-ssd)
- [ ] REC rodando (3 nodes)
- [ ] LoadBalancer com IP externo
- [ ] Database criado e acessível

### **Active-Active:**
- [ ] 2+ RECs rodando em clusters diferentes
- [ ] Conectividade entre clusters validada
- [ ] Certificados TLS configurados
- [ ] Database Active-Active criado
- [ ] Replicação funcionando (teste write/read)
- [ ] Conflict resolution testado

---

## 📊 Comparação Rápida

| Característica | GDC (Bare Metal) | GKE (Cloud) | Active-Active |
|----------------|------------------|-------------|---------------|
| **Ambiente** | On-premises | Google Cloud | Multi-cluster |
| **Storage** | Local/Ceph | Persistent Disk | Qualquer |
| **LoadBalancer** | MetalLB | GCP LB | Ambos |
| **Custo** | Hardware próprio | Pay-as-you-go | 2x+ clusters |
| **Latência** | Baixa (local) | Média (região) | Depende da distância |
| **HA** | Manual (nodes) | Auto (GKE) | Geo-redundância |
| **Complexidade** | Alta | Baixa | Muito Alta |
| **Use Case** | Edge, air-gap | Cloud-native | DR, multi-region |

---

## 🎯 Discussion Questions with Examples

### **GDC (Google Distributed Cloud):**

**1. Which storage backend are we using?**
   - **Options:**
     - Local PV (local SSDs on nodes)
     - Rook/Ceph (distributed storage)
     - Portworx (enterprise storage)
     - OpenEBS (cloud-native storage)
   - **Example Answer:** "We're using Rook/Ceph with 3 OSD nodes, 1TB SSD each"
   - **Why it matters:** Redis needs persistent storage for data durability

**2. Is MetalLB configured? What IP pool?**
   - **Example Answer:** "Yes, MetalLB with IP pool 192.168.1.100-192.168.1.150"
   - **Why it matters:** Bare metal needs LoadBalancer for external access
   - **Validation:**
     ```bash
     kubectl get configmap config -n metallb-system
     kubectl get ipaddresspool -n metallb-system
     ```

**3. How many physical nodes? What specs?**
   - **Example Answer:** "5 nodes: 3 for Redis (32 vCPU, 128GB RAM), 2 for system (16 vCPU, 64GB RAM)"
   - **Why it matters:** Redis Enterprise needs minimum resources per node
   - **Minimum per Redis node:**
     - CPU: 4 cores
     - RAM: 16GB
     - Disk: 100GB SSD

**4. Are there air-gap or compliance requirements?**
   - **Example Answer:** "Yes, air-gapped environment. No internet access. HIPAA compliance required"
   - **Why it matters:** Affects image registry, updates, monitoring
   - **Implications:**
     - Need private container registry
     - Manual image uploads
     - Offline documentation

---

### **GKE (Google Kubernetes Engine):**

**1. Which region/zones are we using?**
   - **Example Answer:** "us-central1, zones: us-central1-a, us-central1-b, us-central1-c"
   - **Why it matters:** Multi-zone for HA, latency considerations
   - **Best practice:** Use 3 zones for Redis 3-node cluster

**2. Node pool: how many nodes? Which machine type?**
   - **Example Answer:** "Node pool: 3 nodes, n2-standard-8 (8 vCPU, 32GB RAM)"
   - **Why it matters:** Redis needs dedicated resources
   - **Recommended machine types:**
     - **Small:** n2-standard-4 (4 vCPU, 16GB RAM)
     - **Medium:** n2-standard-8 (8 vCPU, 32GB RAM)
     - **Large:** n2-standard-16 (16 vCPU, 64GB RAM)
   - **Validation:**
     ```bash
     gcloud container node-pools list --cluster=my-cluster
     ```

**3. Storage: pd-ssd or pd-balanced? What size?**
   - **Example Answer:** "pd-ssd, 500GB per node"
   - **Why it matters:** Performance and cost
   - **Comparison:**
     - **pd-ssd:** Fast (IOPS: 30/GB), expensive ($0.17/GB/month)
     - **pd-balanced:** Medium (IOPS: 6/GB), cheaper ($0.10/GB/month)
     - **pd-standard:** Slow (IOPS: 0.75/GB), cheapest ($0.04/GB/month)
   - **Recommendation:** Use pd-ssd for production

**4. Private GKE or public?**
   - **Example Answer:** "Private GKE with authorized networks: 10.0.0.0/8"
   - **Why it matters:** Security, compliance
   - **Options:**
     - **Public:** Control plane has public IP
     - **Private:** Control plane only accessible from VPC
   - **Validation:**
     ```bash
     gcloud container clusters describe my-cluster --format="value(privateClusterConfig.enablePrivateNodes)"
     ```

**5. VPC/Firewall integration?**
   - **Example Answer:** "Custom VPC 'prod-vpc', subnet 10.10.0.0/16, firewall allows 6379-6380"
   - **Why it matters:** Network isolation, security
   - **Required firewall rules:**
     - Redis ports: 6379-6380 (databases)
     - API port: 9443 (cluster management)
     - UI port: 8443 (web console)

---

### **Active-Active Replication:**

**1. How many clusters? Where are they located?**
   - **Example Answer:** "3 clusters: us-central1 (GKE), us-east1 (GKE), on-prem datacenter (GDC)"
   - **Why it matters:** Topology affects latency, cost, complexity
   - **Common topologies:**
     - **2 clusters:** Simple DR (disaster recovery)
     - **3 clusters:** Multi-region HA
     - **5+ clusters:** Global distribution

**2. What's the latency between clusters?**
   - **Example Answer:** "us-central1 ↔ us-east1: 35ms, us-central1 ↔ on-prem: 80ms"
   - **Why it matters:** High latency affects replication performance
   - **Recommendations:**
     - **< 50ms:** Excellent
     - **50-100ms:** Good
     - **> 100ms:** May have replication lag
   - **Test command:**
     ```bash
     # From cluster A to cluster B
     ping <cluster-b-endpoint>
     ```

**3. What bandwidth is available?**
   - **Example Answer:** "1 Gbps dedicated link between clusters"
   - **Why it matters:** Replication throughput
   - **Calculation:**
     - 1000 writes/sec × 1KB/write = 1 MB/sec
     - Need 2x bandwidth for safety: 2 MB/sec minimum
   - **Recommendation:** 100 Mbps minimum, 1 Gbps for production

**4. Which conflict resolution strategy?**
   - **Example Answer:** "LWW (Last-Write-Wins) for user sessions, Counter for analytics"
   - **Why it matters:** Determines how conflicts are resolved
   - **Strategies:**
     - **LWW (Last-Write-Wins):** Latest timestamp wins
       - Use case: User profiles, sessions
     - **Counter:** Increment/decrement operations
       - Use case: Page views, likes, votes
     - **Set:** Union of all sets
       - Use case: Tags, categories
   - **Example:**
     ```
     Cluster A writes: user:123 = {name: "John", age: 30}
     Cluster B writes: user:123 = {name: "John", age: 31}
     Result (LWW): user:123 = {name: "John", age: 31} (latest wins)
     ```

**5. Automatic or manual failover?**
   - **Example Answer:** "Automatic failover with 30-second timeout"
   - **Why it matters:** RTO (Recovery Time Objective)
   - **Options:**
     - **Automatic:** DNS/Load balancer switches automatically
       - RTO: < 1 minute
     - **Manual:** Ops team switches traffic
       - RTO: 5-30 minutes
   - **Implementation:**
     ```yaml
     # Example: Global Load Balancer with health checks
     healthCheck:
       checkIntervalSec: 10
       timeoutSec: 5
       unhealthyThreshold: 2
     ```

**6. How to monitor replication lag?**
   - **Example Answer:** "Prometheus metrics + Grafana dashboard, alert if lag > 10 seconds"
   - **Why it matters:** Detect replication issues early
   - **Metrics to monitor:**
     - `redis_replication_lag_seconds` - Time delay
     - `redis_replication_backlog_bytes` - Data pending
     - `redis_syncer_status` - Syncer health
   - **Alert example:**
     ```yaml
     alert: HighReplicationLag
     expr: redis_replication_lag_seconds > 10
     for: 5m
     annotations:
       summary: "Replication lag is {{ $value }}s"
     ```

**7. What's the failover test plan?**
   - **Example Answer:** "Monthly test: shutdown cluster A, verify cluster B serves traffic, measure RTO"
   - **Why it matters:** Validate DR works before real disaster
   - **Test steps:**
     1. Write test data to cluster A
     2. Verify replication to cluster B
     3. Simulate cluster A failure
     4. Verify cluster B serves reads/writes
     5. Measure time to failover (RTO)
     6. Restore cluster A
     7. Verify data sync back

**8. What's the data consistency requirement?**
   - **Example Answer:** "Eventual consistency acceptable, max 5 seconds lag"
   - **Why it matters:** Affects architecture decisions
   - **Consistency levels:**
     - **Strong consistency:** Not possible with Active-Active
     - **Eventual consistency:** Data syncs eventually (seconds/minutes)
     - **Causal consistency:** Maintains cause-effect order
   - **Trade-offs:**
     - Stronger consistency = Higher latency
     - Weaker consistency = Better performance

---

## 🚀 Next Steps (Post-Meeting)

### **If GDC Approved:**
- [ ] Provision hardware/VMs
  - **Example:** 5 bare metal servers, 32 vCPU, 128GB RAM each
- [ ] Install Kubernetes (Anthos/kubeadm)
  - **Example:** `kubeadm init --pod-network-cidr=10.244.0.0/16`
- [ ] Configure storage backend
  - **Example:** Deploy Rook/Ceph with 3 OSD nodes
- [ ] Install MetalLB
  - **Example:** IP pool 192.168.1.100-150
- [ ] Deploy Redis Enterprise
  - **Timeline:** 1-2 weeks

### **If GKE Approved:**
- [ ] Create GKE cluster (Terraform or Console)
  - **Example:** `gcloud container clusters create redis-cluster --num-nodes=3 --machine-type=n2-standard-8`
- [ ] Configure node pools
  - **Example:** Dedicated node pool for Redis with taints
- [ ] Deploy Redis Enterprise
  - **Timeline:** 1-3 days
- [ ] Configure LoadBalancer/Ingress
  - **Example:** External LoadBalancer for database access
- [ ] Performance testing
  - **Example:** redis-benchmark, memtier_benchmark

### **If Active-Active Approved:**
- [ ] Provision clusters (GDC/GKE)
  - **Example:** 2 GKE clusters in different regions
- [ ] Configure networking between clusters
  - **Example:** VPN tunnel or VPC peering
- [ ] Configure TLS/certificates
  - **Example:** cert-manager with syncer certificates
- [ ] Deploy RECs in all clusters
  - **Timeline:** 1 week per cluster
- [ ] Create Active-Active database
  - **Example:** CRDB with LWW conflict resolution
- [ ] Test replication and failover
  - **Example:** Write to cluster A, read from cluster B, measure lag

---

## 📝 Meeting Notes

**Participants:**
-

**Decisions Made:**
-

**Action Items:**
| Task | Owner | Deadline |
|------|-------|----------|
|      |       |          |

**Next Meeting:**
- **Date:**
- **Topics:**

**Questions/Concerns Raised:**
-

**Risks Identified:**
-

---

## 📚 Quick References

### **Documentation:**
- GDC: `gdc/README.md`
- GKE: `gke/README.md`
- Active-Active: `active-active/README.md`
- TLS/cert-manager: `security/tls-certificates/cert-manager/README.md`

### **Useful Commands:**

**GDC:**
```bash
# Check nodes
kubectl get nodes -o wide

# Check storage
kubectl get storageclass
kubectl get pv

# Check Redis cluster
kubectl get rec -n redis-enterprise
kubectl describe rec rec -n redis-enterprise

# Check MetalLB
kubectl get configmap -n metallb-system
kubectl get svc -n redis-enterprise
```

**GKE:**
```bash
# Check GKE cluster
gcloud container clusters list
gcloud container clusters describe my-cluster

# Check nodes
kubectl get nodes -o wide
kubectl top nodes

# Check Redis cluster
kubectl get rec -n redis-enterprise
kubectl get svc -n redis-enterprise

# Check persistent disks
kubectl get pv
gcloud compute disks list
```

**Active-Active:**
```bash
# Cluster A
kubectl get rec -n redis-enterprise --context=cluster-a
kubectl get redb -n redis-enterprise --context=cluster-a

# Cluster B
kubectl get rec -n redis-enterprise --context=cluster-b
kubectl get redb -n redis-enterprise --context=cluster-b

# Check replication status
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status

# Check replication lag
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin status databases extra all | grep -i lag

# Test connectivity between clusters
kubectl exec -it rec-0 -n redis-enterprise --context=cluster-a -- \
  ping <cluster-b-endpoint>
```

### **Performance Testing:**

```bash
# redis-benchmark (built-in)
redis-benchmark -h <host> -p <port> -a <password> \
  -t set,get -n 100000 -c 50

# memtier_benchmark (advanced)
memtier_benchmark -s <host> -p <port> -a <password> \
  --protocol=redis --clients=50 --threads=4 \
  --ratio=1:10 --data-size=1024 --requests=10000

# Expected results:
# - Throughput: 100K+ ops/sec
# - Latency p99: < 5ms
# - Latency p50: < 1ms
```

---

## 🎯 Decision Matrix

Use this to help make decisions during the meeting:

| Requirement | GDC | GKE | Active-Active |
|-------------|-----|-----|---------------|
| **On-premises required** | ✅ Yes | ❌ No | ⚠️ Hybrid |
| **Air-gap environment** | ✅ Yes | ❌ No | ⚠️ Partial |
| **Cloud-native** | ❌ No | ✅ Yes | ✅ Yes |
| **Multi-region HA** | ❌ No | ⚠️ Partial | ✅ Yes |
| **Disaster Recovery** | ⚠️ Manual | ⚠️ Manual | ✅ Automatic |
| **Operational complexity** | 🔴 High | 🟢 Low | 🔴 Very High |
| **Initial setup time** | 🔴 2-4 weeks | 🟢 1-3 days | 🔴 2-6 weeks |
| **Cost (relative)** | 💰💰💰 | 💰💰 | 💰💰💰💰 |
| **Scalability** | ⚠️ Limited | ✅ High | ✅ Very High |
| **Compliance (data residency)** | ✅ Full control | ⚠️ GCP regions | ✅ Full control |

**Legend:**
- ✅ = Excellent fit
- ⚠️ = Possible with caveats
- ❌ = Not suitable
- 🟢 = Easy
- 🔴 = Difficult
- 💰 = Cost level

---

**✅ Document ready for review meeting**

