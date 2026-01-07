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

## 🎯 Perguntas para Discussão

### **GDC:**
1. Qual storage backend estamos usando? (Local PV, Rook, Ceph, Portworx?)
2. MetalLB está configurado? Qual IP pool?
3. Quantos nodes físicos temos? Specs?
4. Há requisitos de air-gap ou compliance?

### **GKE:**
1. Qual região/zona estamos usando?
2. Node pool: quantos nodes? Qual machine type?
3. Storage: pd-ssd ou pd-balanced? Tamanho?
4. Precisa de Private GKE ou pode ser público?
5. Integração com VPC/Firewall?

### **Active-Active:**
1. Quantos clusters? Onde estão localizados?
2. Latência entre clusters? (ping test)
3. Bandwidth disponível?
4. Qual estratégia de conflict resolution? (LWW, Counter, etc)
5. Failover automático ou manual?
6. Monitoramento de replicação lag?

---

## 🚀 Próximos Passos (Pós-Reunião)

### **Se aprovado GDC:**
- [ ] Provisionar hardware/VMs
- [ ] Instalar Kubernetes (Anthos/kubeadm)
- [ ] Configurar storage backend
- [ ] Instalar MetalLB
- [ ] Deploy Redis Enterprise

### **Se aprovado GKE:**
- [ ] Criar cluster GKE (Terraform ou Console)
- [ ] Configurar node pools
- [ ] Deploy Redis Enterprise
- [ ] Configurar LoadBalancer/Ingress
- [ ] Testes de performance

### **Se aprovado Active-Active:**
- [ ] Provisionar clusters (GDC/GKE)
- [ ] Configurar networking entre clusters
- [ ] Configurar TLS/certificados
- [ ] Deploy RECs em todos clusters
- [ ] Criar database Active-Active
- [ ] Testes de replicação e failover

---

## 📝 Notas da Reunião

**Participantes:**
-

**Decisões:**
-

**Action Items:**
-

**Próxima Reunião:**
-

---

## 📚 Referências Rápidas

### **Documentação:**
- GDC: `gdc/README.md`
- GKE: `gke/README.md`
- Active-Active: `active-active/README.md`
- TLS/cert-manager: `security/tls-certificates/cert-manager/README.md`

### **Comandos Úteis:**

**GDC:**
```bash
kubectl get nodes -o wide
kubectl get storageclass
kubectl get rec -n redis-enterprise
```

**GKE:**
```bash
gcloud container clusters list
kubectl get nodes
kubectl get svc -n redis-enterprise
```

**Active-Active:**
```bash
# Cluster A
kubectl get rec -n redis-enterprise --context=cluster-a

# Cluster B
kubectl get rec -n redis-enterprise --context=cluster-b

# Verificar replicação
kubectl exec -it rec-0 -n redis-enterprise -- rladmin status
```

---

**✅ Documento preparado para reunião de revisão**

