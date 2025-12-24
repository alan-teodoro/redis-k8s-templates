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
├── operator/                   # Redis Enterprise Operator installation & management
├── deployments/                # Redis Enterprise deployment patterns
│   └── redis-enterprise/
│       ├── single-cluster/     # Standard single-cluster deployments
│       ├── active-active/      # Multi-cluster Active-Active
│       ├── active-passive/     # Disaster recovery configurations
│       └── modules/            # Deployments with Redis modules
│
├── platforms/                  # Platform-specific configurations
│   ├── eks/                    # AWS Elastic Kubernetes Service
│   ├── aks/                    # Azure Kubernetes Service
│   ├── gke/                    # Google Kubernetes Engine
│   ├── openshift/              # Red Hat OpenShift
│   └── vanilla/                # Generic Kubernetes
│
├── integrations/               # Third-party tool integrations
│   ├── argocd/                 # GitOps with ArgoCD
│   ├── vault/                  # HashiCorp Vault for secrets
│   ├── cert-manager/           # Certificate management
│   ├── ingress/                # Ingress controllers (NGINX, Traefik, etc.)
│   └── service-mesh/           # Service mesh integrations
│
├── monitoring/                 # Monitoring & observability
│   ├── prometheus/             # Prometheus integration
│   ├── grafana/                # Grafana dashboards
│   ├── datadog/                # Datadog integration
│   └── newrelic/               # New Relic integration
│
├── security/                   # Security configurations
│   ├── tls/                    # TLS/SSL certificates
│   ├── rbac/                   # Role-based access control
│   ├── network-policies/       # Network isolation
│   ├── pod-security/           # Pod security policies/standards
│   └── secrets-management/     # Secrets management solutions
│
├── networking/                 # Networking configurations
│   ├── services/               # Service types (ClusterIP, LoadBalancer, etc.)
│   ├── ingress/                # Ingress configurations
│   └── dns/                    # DNS configurations
│
├── storage/                    # Storage configurations
│   ├── storage-classes/        # Platform-specific storage classes
│   └── pvc-examples/           # PVC examples
│
├── backup-restore/             # Backup and restore procedures
├── disaster-recovery/          # DR strategies and runbooks
├── testing/                    # Testing and validation tools
├── automation/                 # Automation scripts and IaC
├── examples/                   # End-to-end scenario examples
└── docs/                       # Quick reference guides
```

## 🚀 Quick Start

### For OpenShift Users
The most complete examples are currently in the OpenShift section:
- **Single-region deployment**: [`platforms/openshift/single-region/`](platforms/openshift/single-region/)
- **Active-Active deployment**: [`platforms/openshift/active-active/`](platforms/openshift/active-active/)

Each includes:
- Step-by-step deployment guide
- All required YAML files
- Connection and testing instructions

### For Other Platforms
Content for EKS, AKS, GKE, and vanilla Kubernetes is being added progressively. Check the respective platform directories.

## 📚 Documentation

- **[Deployment Patterns](docs/deployment-patterns.md)** - When to use which deployment pattern
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and solutions
- **[Security Checklist](docs/security-checklist.md)** - Security best practices
- **[Sizing Guide](docs/sizing-guide.md)** - Resource sizing recommendations

## 🎯 Common Use Cases

| Use Case | Location | Description |
|----------|----------|-------------|
| Single-cluster deployment | `deployments/redis-enterprise/single-cluster/` | Standard Redis Enterprise cluster |
| Active-Active geo-distribution | `deployments/redis-enterprise/active-active/` | Multi-region with CRDT replication |
| OpenShift deployment | `platforms/openshift/` | Complete OpenShift examples |
| ArgoCD GitOps | `integrations/argocd/` | GitOps deployment patterns |
| Vault secrets integration | `integrations/vault/` | Secrets management with Vault |
| Prometheus monitoring | `monitoring/prometheus/` | Metrics and alerting |

## 🔧 Prerequisites

- Kubernetes cluster (1.23+) or OpenShift (4.10+)
- kubectl or oc CLI configured
- Cluster admin access (for operator installation)
- Sufficient resources (see sizing guide)

## 📖 How to Use This Repository

1. **Find your platform**: Navigate to `platforms/<your-platform>/`
2. **Choose deployment pattern**: Check `deployments/redis-enterprise/<pattern>/`
3. **Review integrations**: Add monitoring, secrets management, etc. from `integrations/`
4. **Follow step-by-step guides**: Each section has README.md with deployment steps
5. **Test and validate**: Use tools from `testing/` directory

## 🤝 Contributing

This is a living reference repository. When adding new content:
- Follow the existing documentation style (see OpenShift examples)
- Include step-by-step deployment instructions
- Test all YAML files before committing
- Keep documentation concise and reference-focused
- No conceptual explanations - focus on "how-to"

## 📞 Support

For Redis Professional Services team and customers:
- Internal: Contact Redis PS team
- Customers: Reach out to your Redis account team

## 📄 License

Internal Redis Professional Services resource.
