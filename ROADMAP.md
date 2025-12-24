# Redis Enterprise on Kubernetes - Content Roadmap

This document tracks what content needs to be added to complete this reference repository.

## ✅ Completed

- [x] Repository restructure
- [x] Main README with navigation
- [x] OpenShift complete examples (single-region, active-active)
- [x] ArgoCD integration examples
- [x] Vault integration basics
- [x] Documentation structure (deployment-patterns, troubleshooting)
- [x] Operator README structure

## 📋 Content Plan by Priority

### Phase 1: Core Operator & Deployments (PRIORITY 1)

#### Operator Installation
- [ ] **operator/installation/helm/** - Helm-based installation guide
  - [ ] README.md with step-by-step instructions
  - [ ] values.yaml examples (minimal, production)
  - [ ] Installation script
  
- [ ] **operator/installation/olm/** - OpenShift OLM installation
  - [ ] README.md
  - [ ] Subscription YAML
  - [ ] OperatorGroup YAML
  
- [ ] **operator/installation/manual/** - Manual YAML installation
  - [ ] README.md
  - [ ] All operator YAMLs (CRDs, RBAC, deployment)
  - [ ] Installation order guide

- [ ] **operator/upgrades/** - Upgrade procedures
  - [ ] README.md with upgrade process
  - [ ] Version compatibility matrix
  - [ ] Rollback procedures

- [ ] **operator/configuration/** - Operator configuration
  - [ ] README.md
  - [ ] Resource limits examples
  - [ ] Image pull secrets
  - [ ] Admission controller config

#### Single-Cluster Deployments
- [ ] **deployments/redis-enterprise/single-cluster/** - Basic deployments
  - [ ] README.md with architecture and steps
  - [ ] Minimal deployment (3-node, basic config)
  - [ ] Production deployment (resource limits, persistence)
  - [ ] With modules (JSON, Search, etc.)

#### Active-Active Deployments
- [ ] **deployments/redis-enterprise/active-active/** - Multi-cluster AA
  - [ ] README.md with architecture
  - [ ] 2-cluster example
  - [ ] 3+ cluster example
  - [ ] Cross-cloud example (EKS + AKS)

#### Active-Passive Deployments
- [ ] **deployments/redis-enterprise/active-passive/** - DR configurations
  - [ ] README.md
  - [ ] Replica-of configuration
  - [ ] Failover procedures
  - [ ] Backup/restore integration

---

### Phase 2: Platform-Specific Content (PRIORITY 2)

#### EKS (AWS)
- [ ] **platforms/eks/storage/** - EBS CSI and storage classes
  - [ ] README.md
  - [ ] EBS CSI driver installation
  - [ ] Storage class examples (gp3, io2)
  - [ ] PVC examples

- [ ] **platforms/eks/networking/** - VPC, security groups, load balancers
  - [ ] README.md
  - [ ] NLB service examples
  - [ ] ALB ingress examples
  - [ ] Security group configurations
  - [ ] VPC peering for Active-Active

- [ ] **platforms/eks/iam/** - IAM roles and IRSA
  - [ ] README.md
  - [ ] IRSA setup guide
  - [ ] IAM policies for secrets access
  - [ ] KMS integration

- [ ] **platforms/eks/examples/** - Complete deployments
  - [ ] Basic single-cluster
  - [ ] HA with NLB
  - [ ] With AWS Secrets Manager
  - [ ] Multi-region Active-Active

#### AKS (Azure)
- [ ] **platforms/aks/storage/** - Azure Disk CSI
  - [ ] README.md
  - [ ] Azure Disk CSI setup
  - [ ] Storage class examples (Premium SSD, Ultra Disk)
  - [ ] PVC examples

- [ ] **platforms/aks/networking/** - VNET, NSG, load balancers
  - [ ] README.md
  - [ ] Azure Load Balancer examples
  - [ ] Internal LB configuration
  - [ ] NSG rules
  - [ ] VNET peering for Active-Active

- [ ] **platforms/aks/identity/** - Managed Identity
  - [ ] README.md
  - [ ] Managed Identity setup
  - [ ] Azure Key Vault integration
  - [ ] RBAC configuration

- [ ] **platforms/aks/examples/** - Complete deployments
  - [ ] Basic single-cluster
  - [ ] HA with Azure LB
  - [ ] With Azure Key Vault
  - [ ] Multi-region Active-Active

#### GKE (Google Cloud)
- [ ] **platforms/gke/storage/** - Persistent Disk CSI
  - [ ] README.md
  - [ ] PD CSI setup
  - [ ] Storage class examples (pd-ssd, pd-balanced)
  - [ ] PVC examples

- [ ] **platforms/gke/networking/** - VPC, firewall, load balancers
  - [ ] README.md
  - [ ] GCP Load Balancer examples
  - [ ] Internal LB configuration
  - [ ] Firewall rules
  - [ ] VPC peering for Active-Active

- [ ] **platforms/gke/identity/** - Workload Identity
  - [ ] README.md
  - [ ] Workload Identity setup
  - [ ] Secret Manager integration
  - [ ] IAM configuration

- [ ] **platforms/gke/examples/** - Complete deployments
  - [ ] Basic single-cluster
  - [ ] HA with GCP LB
  - [ ] With Secret Manager
  - [ ] Multi-region Active-Active

#### Vanilla Kubernetes
- [ ] **platforms/vanilla/on-premises/** - On-prem K8s
  - [ ] README.md
  - [ ] Local storage configuration
  - [ ] MetalLB for LoadBalancer
  - [ ] Complete deployment example

- [ ] **platforms/vanilla/managed/** - Generic managed K8s
  - [ ] README.md
  - [ ] Generic storage classes
  - [ ] Generic load balancer config
  - [ ] Deployment examples

---

### Phase 3: Integrations (PRIORITY 3)

#### Vault Integration
- [ ] **integrations/vault/setup/** - Vault installation
  - [ ] README.md
  - [ ] Vault Helm installation
  - [ ] Vault configuration for Redis
  - [ ] Policy examples

- [ ] **integrations/vault/external-secrets/** - ESO integration
  - [ ] README.md
  - [ ] External Secrets Operator setup
  - [ ] SecretStore configuration
  - [ ] ExternalSecret examples

#### Cert-Manager
- [ ] **integrations/cert-manager/** - Certificate management
  - [ ] README.md
  - [ ] Cert-manager installation
  - [ ] Issuer examples (self-signed, Let's Encrypt, CA)
  - [ ] Certificate examples for Redis

#### Ingress Controllers
- [ ] **integrations/ingress/nginx/** - NGINX Ingress
- [ ] **integrations/ingress/traefik/** - Traefik
- [ ] **integrations/ingress/istio/** - Istio Gateway
- [ ] **integrations/ingress/ambassador/** - Ambassador

Each with:
  - [ ] README.md
  - [ ] Installation guide
  - [ ] Redis-specific configuration
  - [ ] TLS termination examples

---

### Phase 4: Security, Monitoring, Testing (PRIORITY 4)

See ROADMAP.md for complete phase 4-6 details.

---

## Current Focus

**Next immediate tasks:**
1. Complete operator installation guides (Helm, OLM, manual)
2. Create single-cluster deployment examples
3. Complete EKS platform-specific content
4. Add monitoring (Prometheus/Grafana) integration

---

## How to Contribute

When adding content:
1. Follow the OpenShift documentation style (clear, step-by-step)
2. Include README.md in each directory
3. Test all YAML files before committing
4. Update this roadmap when completing items
5. Keep documentation concise and reference-focused

