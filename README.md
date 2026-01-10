# Redis Enterprise on Kubernetes - Reference Repository

**Professional Services Reference Repository** for deploying and managing Redis Enterprise on Kubernetes across multiple platforms and cloud providers.

## 📋 Purpose

This repository serves as a comprehensive reference for Redis Professional Services team and customers to:
- Deploy Redis Enterprise in various Kubernetes environments (EKS, AKS, GKE, OpenShift, vanilla K8s)
- Prepare pre-production and production environments
- Conduct customer engagements, demos, and workshops
- Practice and reproduce customer scenarios
- Reference tested, production-ready configurations

**Note**: This is a **reference repository** - documentation is concise and focused on practical deployment steps, not conceptual explanations.

## 🗂️ Repository Structure

```
redis-k8s-templates/
│
├── platforms/                  # Platform-specific cluster setup
│   ├── eks/                    # AWS Elastic Kubernetes Service
│   ├── aks/                    # Azure Kubernetes Service
│   ├── gke/                    # Google Kubernetes Engine
│   └── openshift/              # Red Hat OpenShift
│
├── deployments/                # Redis Enterprise deployment patterns
│   ├── single-region/          # Standard single-region deployments
│   ├── active-active/          # Multi-region Active-Active (CRDB)
│   ├── multi-namespace/        # Multi-namespace REDB deployments
│   ├── redis-on-flash/         # Redis on Flash (RAM + SSD tiering)
│   ├── rdi/                    # RDI (Redis Data Integration) - CDC from relational DBs
│   └── redisinsight/           # RedisInsight management UI
│
├── networking/                 # Networking solutions
│   ├── gateway-api/            # Kubernetes Gateway API (NGINX Gateway Fabric)
│   ├── ingress/                # Ingress controllers (NGINX, HAProxy, Istio)
│   └── in-cluster/             # In-cluster networking
│
├── security/                   # Security configurations
│   ├── tls-certificates/       # TLS/SSL certificates (Custom CA, cert-manager)
│   ├── external-secrets/       # External Secrets Operator (AWS/Azure/GCP)
│   ├── network-policies/       # Kubernetes Network Policies
│   ├── pod-security/           # Pod Security Standards
│   └── rbac/                   # Kubernetes RBAC
│
├── backup-restore/             # Backup & Restore
│   ├── s3/                     # AWS S3 backups
│   ├── gcs/                    # Google Cloud Storage backups
│   └── azure-blob/             # Azure Blob Storage backups
│
├── integrations/               # Third-party integrations
│   ├── argocd/                 # GitOps with ArgoCD
│   ├── vault/                  # HashiCorp Vault for secrets
│   └── istio/                  # Istio Service Mesh
│
├── monitoring/                 # Monitoring stack
│   ├── prometheus/             # Prometheus + ServiceMonitor
│   └── grafana/                # Grafana dashboards
│
├── observability/              # Logging & Observability
│   ├── logging/                # Logging solutions
│   │   └── loki/               # Grafana Loki + Promtail
│   └── rdi/                    # RDI observability (Prometheus metrics, Grafana dashboards)
│
├── operations/                 # Operational guides
│   ├── ha-disaster-recovery/   # HA & DR strategies
│   ├── troubleshooting/        # Troubleshooting guides
│   ├── capacity-planning/      # Capacity planning & sizing
│   └── node-management/        # Node selection, QoS, eviction thresholds
│
└── best-practices/             # Best practices guide
```

---

## 🚀 Quick Start

### 1. Platform Setup

Choose your platform and follow the setup guide:

| Platform | Guide | Description |
|----------|-------|-------------|
| **AWS EKS** | [platforms/eks/](platforms/eks/) | Complete EKS cluster setup with Redis Enterprise |
| **OpenShift** | [platforms/openshift/](platforms/openshift/) | OpenShift deployment examples (gold standard) |

### 2. Deployment Pattern

Choose your deployment pattern:

| Pattern | Guide | Use Case |
|---------|-------|----------|
| **Single-Region** | [deployments/single-region/](deployments/single-region/) | Standard production deployment |
| **Active-Active** | [deployments/active-active/](deployments/active-active/) | Multi-region, geo-distributed |
| **Multi-Namespace** | [deployments/multi-namespace/](deployments/multi-namespace/) | Isolated databases across namespaces |
| **Redis on Flash** | [deployments/redis-on-flash/](deployments/redis-on-flash/) | RAM + SSD tiering (cost optimization) |
| **RDI (CDC)** | [deployments/rdi/](deployments/rdi/) | Real-time data integration from relational DBs |
| **RedisInsight** | [deployments/redisinsight/](deployments/redisinsight/) | Management UI and monitoring tool |

### 3. Essential Components

Configure essential components for production:

| Component | Guide | Priority |
|-----------|-------|----------|
| **Backup & Restore** | [backup-restore/](backup-restore/) | 🔴 CRITICAL |
| **Security** | [security/](security/) | 🔴 CRITICAL |
| **Monitoring** | [monitoring/](monitoring/) | 🟡 IMPORTANT |
| **Networking** | [networking/](networking/) | 🟡 IMPORTANT |
| **Logging** | [observability/logging/](observability/logging/) | 🟢 RECOMMENDED |

---

## 📚 Documentation by Topic

### 🔐 Security

| Topic | Guide | Description |
|-------|-------|-------------|
| **TLS Certificates** | [security/tls-certificates/](security/tls-certificates/) | Custom CA, cert-manager integration |
| **External Secrets** | [security/external-secrets/](security/external-secrets/) | AWS/Azure/GCP secret management |
| **Network Policies** | [security/network-policies/](security/network-policies/) | Zero-trust network security |
| **Pod Security** | [security/pod-security/](security/pod-security/) | Pod Security Standards |
| **RBAC** | [security/rbac/](security/rbac/) | Kubernetes RBAC configuration |

### 💾 Backup & Disaster Recovery

| Topic | Guide | Description |
|-------|-------|-------------|
| **S3 Backups** | [backup-restore/s3/](backup-restore/s3/) | AWS S3 backup configuration |
| **GCS Backups** | [backup-restore/gcs/](backup-restore/gcs/) | Google Cloud Storage backups |
| **Azure Backups** | [backup-restore/azure-blob/](backup-restore/azure-blob/) | Azure Blob Storage backups |
| **HA & DR** | [operations/ha-disaster-recovery/](operations/ha-disaster-recovery/) | High availability and DR strategies |

### 🌐 Networking

| Topic | Guide | Description |
|-------|-------|-------------|
| **Gateway API** | [networking/gateway-api/](networking/gateway-api/) | NGINX Gateway Fabric |
| **NGINX Ingress** | [networking/ingress/nginx/](networking/ingress/nginx/) | NGINX Ingress Controller |
| **HAProxy Ingress** | [networking/ingress/haproxy/](networking/ingress/haproxy/) | HAProxy Ingress Controller |
| **Istio** | [integrations/istio/](integrations/istio/) | Istio Service Mesh |

### 📊 Monitoring & Observability

| Topic | Guide | Description |
|-------|-------|-------------|
| **Prometheus** | [monitoring/prometheus/](monitoring/prometheus/) | Metrics collection and alerting |
| **Grafana** | [monitoring/grafana/](monitoring/grafana/) | Dashboards and visualization |
| **Loki** | [observability/logging/loki/](observability/logging/loki/) | Log aggregation and querying |
| **RDI Observability** | [observability/rdi/](observability/rdi/) | RDI metrics, dashboards, and alerts |

### � Operations

| Topic | Guide | Description |
|-------|-------|-------------|
| **Troubleshooting** | [operations/troubleshooting/](operations/troubleshooting/) | Common issues and solutions |
| **Capacity Planning** | [operations/capacity-planning/](operations/capacity-planning/) | Resource sizing and planning |
| **Node Management** | [operations/node-management/](operations/node-management/) | Node selection, QoS, eviction thresholds, resource quotas |
| **Best Practices** | [best-practices/](best-practices/) | Production best practices |

### 🔗 Integrations

| Topic | Guide | Description |
|-------|-------|-------------|
| **ArgoCD** | [integrations/argocd/](integrations/argocd/) | GitOps deployment |
| **HashiCorp Vault** | [integrations/vault/](integrations/vault/) | Secrets management |

### 🔄 RDI (Redis Data Integration)

| Topic | Guide | Description |
|-------|-------|-------------|
| **RDI Deployment** | [deployments/rdi/](deployments/rdi/) | Helm chart installation, database setup |
| **Source DB Prep** | [deployments/rdi/08-source-database-prep.md](deployments/rdi/08-source-database-prep.md) | PostgreSQL, MySQL, Oracle, SQL Server CDC setup |
| **Pipeline Examples** | [deployments/rdi/09-pipeline-examples.md](deployments/rdi/09-pipeline-examples.md) | Real-world pipeline configurations |
| **RDI Observability** | [observability/rdi/](observability/rdi/) | Prometheus metrics, Grafana dashboards, alerts |
| **Troubleshooting** | [deployments/rdi/10-troubleshooting.md](deployments/rdi/10-troubleshooting.md) | Common issues, logs, support package |

**RDI** (Redis Data Integration) enables real-time data replication from relational databases (Oracle, PostgreSQL, MySQL, SQL Server) to Redis using Change Data Capture (CDC). Perfect for:
- **Cache modernization**: Sync relational data to Redis for ultra-fast access
- **Event-driven architectures**: Stream database changes in real-time
- **Microservices data**: Keep Redis in sync with source of truth databases
- **Real-time analytics**: Process database changes as they happen

---

## 🎯 Common Scenarios

### Scenario 1: New Production Deployment on AWS

1. ✅ [Setup EKS cluster](platforms/eks/)
2. ✅ [Deploy single-region Redis Enterprise](deployments/single-region/)
3. ✅ [Configure S3 backups](backup-restore/s3/)
4. ✅ [Enable TLS with cert-manager](security/tls-certificates/cert-manager/)
5. ✅ [Setup External Secrets Operator](security/external-secrets/aws/)
6. ✅ [Configure Network Policies](security/network-policies/)
7. ✅ [Setup Prometheus monitoring](monitoring/prometheus/)
8. ✅ [Configure Loki logging](observability/logging/loki/)

### Scenario 2: Multi-Region Active-Active

1. ✅ [Setup clusters in multiple regions](platforms/eks/)
2. ✅ [Deploy Active-Active CRDB](deployments/active-active/)
3. ✅ [Configure cross-region backups](backup-restore/)
4. ✅ [Setup monitoring in each region](monitoring/)
5. ✅ [Test failover procedures](operations/ha-disaster-recovery/)

### Scenario 3: Security Hardening

1. ✅ [Enable TLS everywhere](security/tls-certificates/)
2. ✅ [Configure External Secrets](security/external-secrets/)
3. ✅ [Apply Network Policies](security/network-policies/)
4. ✅ [Enable Pod Security Standards](security/pod-security/)
5. ✅ [Configure RBAC](security/rbac/)
6. ✅ [Review best practices](best-practices/)

### Scenario 4: Real-Time Data Integration (RDI)

1. ✅ [Deploy Redis Enterprise](deployments/single-region/)
2. ✅ [Create RDI database](deployments/rdi/01-rdi-database.yaml)
3. ✅ [Prepare source database for CDC](deployments/rdi/08-source-database-prep.md)
4. ✅ [Install RDI via Helm](deployments/rdi/)
5. ✅ [Configure pipeline](deployments/rdi/09-pipeline-examples.md)
6. ✅ [Setup RDI monitoring](observability/rdi/)
7. ✅ [Deploy and monitor pipeline](deployments/rdi/10-troubleshooting.md)

---

## 🔧 Prerequisites

- Kubernetes cluster (1.23+) or OpenShift (4.10+)
- kubectl or oc CLI configured
- Cluster admin access (for operator installation)
- Sufficient resources (see [Capacity Planning](operations/capacity-planning/))

---

## 📖 How to Use This Repository

### For Professional Services Teams

1. **Pre-engagement**: Review [Best Practices](best-practices/) and [Capacity Planning](operations/capacity-planning/)
2. **Platform setup**: Follow platform-specific guides in [platforms/](platforms/)
3. **Deployment**: Choose pattern from [deployments/](deployments/)
4. **Security**: Implement security controls from [security/](security/)
5. **Operations**: Setup monitoring, logging, and backups
6. **Handoff**: Provide [Troubleshooting](operations/troubleshooting/) and [Operations](operations/) guides to customer

### For Customers

1. **Start here**: [Quick Start](#-quick-start) section above
2. **Follow scenarios**: Choose a scenario that matches your use case
3. **Reference documentation**: Each component has detailed README with step-by-step instructions
4. **Get help**: Use [Troubleshooting Guide](operations/troubleshooting/) for common issues

---

## ✅ What's Included

This repository provides **production-ready, tested configurations** for:

### ✅ Complete Platform Setup
- AWS EKS cluster with all prerequisites
- Redis Enterprise Operator installation
- Cluster and database deployment

### ✅ Enterprise Security
- TLS/SSL certificates (Custom CA + cert-manager)
- External Secrets Operator (AWS/Azure/GCP)
- Network Policies (zero-trust)
- Pod Security Standards
- Kubernetes RBAC

### ✅ Backup & Disaster Recovery
- Automated backups to S3/GCS/Azure
- High Availability configuration
- Disaster Recovery strategies
- Restore procedures

### ✅ Networking Solutions
- Gateway API (NGINX Gateway Fabric)
- Ingress Controllers (NGINX, HAProxy)
- Service Mesh (Istio)
- In-cluster networking

### ✅ Monitoring & Observability
- Prometheus metrics collection
- Grafana dashboards
- Loki log aggregation
- Alert rules

### ✅ Operations & Best Practices
- Troubleshooting guides
- Capacity planning and sizing
- Production best practices
- Common scenarios and runbooks

---

## 🎓 Redis Enterprise 8.0 Features

This repository is designed for **Redis Enterprise 8.0**, which includes:

- ✅ **Built-in Modules**: All modules (JSON, Search/Query Engine, TimeSeries, Bloom, etc.) are now native - no separate installation needed
- ✅ **Redis Query Engine**: Vector search for GenAI/RAG applications
- ✅ **Simplified Management**: No more module_args configuration
- ✅ **Enhanced Performance**: Improved query performance and scalability

---

## 🤝 Contributing

This is a living reference repository maintained by Redis Professional Services team.

**Guidelines:**
- Follow existing documentation style
- Include step-by-step deployment instructions
- Test all YAML files before committing
- Keep documentation concise and practical
- Focus on "how-to" rather than conceptual explanations

---