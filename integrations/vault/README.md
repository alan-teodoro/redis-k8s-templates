# HashiCorp Vault Integration with Redis Enterprise

This directory contains reference implementations for integrating Redis Enterprise with HashiCorp Vault for centralized secrets management.

## 📁 Structure

```
vault/
├── external-vault/       # External Vault (VM, Cloud, etc.)
│   └── ...              # K8s configuration for integration only
└── vault-in-cluster/    # Vault running inside Kubernetes
    └── ...              # Vault infrastructure + Redis integration
```

## 🎯 Which Option to Choose?

### 🌐 **External Vault** (`external-vault/`)

**Use when:**
- ✅ You already have Vault running on VM/Cloud
- ✅ Vault manages multiple Kubernetes clusters
- ✅ Compliance requirements demand physical separation
- ✅ Security team manages Vault separately

**What's included:**
- Redis Enterprise Operator configuration for external Vault
- REC and Database manifests with Vault integration
- Troubleshooting for common issues
- Step-by-step configuration guide

**Prerequisites:**
- Vault already installed and configured with HTTPS
- Network connectivity between K8s and Vault
- Security Groups/Firewall configured

**📖 [Go to documentation →](./external-vault/)**

---

### ☸️ **Vault in Cluster** (`vault-in-cluster/`)

**Use when:**
- ✅ Vault is used only for this cluster
- ✅ You want simplicity and automation
- ✅ You need HA without additional complexity
- ✅ You want to reduce costs (no dedicated VMs)

**What's included:**
- Complete Vault deployment in Kubernetes (Helm)
- HA configuration with Raft storage
- Automatic integration with Redis Enterprise
- Everything via Kubernetes manifests

**Advantages:**
- Much simpler setup (everything via kubectl/helm)
- Native HA via StatefulSet
- Minimal latency (internal cluster network)
- No need for external Security Groups

**📖 [Go to documentation →](./vault-in-cluster/)**

---

## 📊 Quick Comparison

| Aspect | External Vault | Vault in Cluster |
|---------|---------------|------------------|
| **Setup Complexity** | 🔴 High | 🟢 Low |
| **Cost** | 🔴 Dedicated VMs | 🟢 Uses existing nodes |
| **HA** | 🔴 Manual | 🟢 Automatic |
| **Latency** | 🔴 External network | 🟢 Internal network |
| **Isolation** | 🟢 Complete | 🟡 Shared |
| **Maintenance** | 🔴 Manual | 🟢 Automated |
| **Multi-cluster** | 🟢 Yes | 🔴 Single cluster only |
| **Compliance** | 🟢 Physical separation | 🟡 Logical separation |

## 🚀 Quick Start

### External Vault
```bash
cd external-vault/
cat README.md
```

### Vault in Cluster
```bash
cd vault-in-cluster/
cat README.md
```

## ⚠️ Important Requirements

**Both options require:**
- ✅ Vault with HTTPS (HTTP is not supported)
- ✅ KV v2 secrets engine enabled
- ✅ Kubernetes auth method configured
- ✅ Policies and roles created in Vault

## 📚 Additional Resources

- [Redis Enterprise Vault Integration](https://redis.io/blog/kubernetes-secret/)
- [Vault Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide)

## 🤝 Contributing

This is a reference project. Adapt to your specific needs.

