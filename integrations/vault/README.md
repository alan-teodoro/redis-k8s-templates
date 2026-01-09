# HashiCorp Vault Integration with Redis Enterprise

Este diretório contém implementações de referência para integrar Redis Enterprise com HashiCorp Vault para gerenciamento centralizado de secrets.

## 📁 Estrutura

```
vault/
├── external-vault/       # Vault externo (VM, Cloud, etc)
│   └── ...              # Apenas configuração K8s para integração
└── vault-in-cluster/    # Vault rodando dentro do Kubernetes
    └── ...              # Infra do Vault + Integração Redis
```

## 🎯 Qual Opção Escolher?

### 🌐 **Vault Externo** (`external-vault/`)

**Use quando:**
- ✅ Já tem Vault rodando em VM/Cloud
- ✅ Vault gerencia múltiplos clusters Kubernetes
- ✅ Requisitos de compliance exigem separação física
- ✅ Equipe de segurança gerencia Vault separadamente

**O que contém:**
- Configuração do Redis Enterprise Operator para Vault externo
- Manifests do REC e Database com integração Vault
- Troubleshooting de problemas comuns
- Guia de configuração passo a passo

**Pré-requisitos:**
- Vault já instalado e configurado com HTTPS
- Conectividade de rede entre K8s e Vault
- Security Groups/Firewall configurados

**📖 [Ir para documentação →](./external-vault/)**

---

### ☸️ **Vault in Cluster** (`vault-in-cluster/`)

**Use quando:**
- ✅ Vault é usado apenas para este cluster
- ✅ Quer simplicidade e automação
- ✅ Precisa de HA sem complexidade adicional
- ✅ Quer reduzir custos (sem VMs dedicadas)

**O que contém:**
- Deploy completo do Vault no Kubernetes (Helm)
- Configuração de HA com Raft storage
- Integração automática com Redis Enterprise
- Tudo via manifests Kubernetes

**Vantagens:**
- Setup muito mais simples (tudo via kubectl/helm)
- HA nativo via StatefulSet
- Latência mínima (rede interna do cluster)
- Sem necessidade de Security Groups externos

**📖 [Ir para documentação →](./vault-in-cluster/)**

---

## 📊 Comparação Rápida

| Aspecto | Vault Externo | Vault in Cluster |
|---------|---------------|------------------|
| **Complexidade Setup** | 🔴 Alta | 🟢 Baixa |
| **Custo** | 🔴 VMs dedicadas | 🟢 Usa nodes existentes |
| **HA** | 🔴 Manual | 🟢 Automático |
| **Latência** | 🔴 Rede externa | 🟢 Rede interna |
| **Isolamento** | 🟢 Total | 🟡 Compartilhado |
| **Manutenção** | 🔴 Manual | 🟢 Automatizada |

## 🚀 Quick Start

### Vault Externo
```bash
cd external-vault/
cat README.md
```

### Vault in Cluster
```bash
cd vault-in-cluster/
cat README.md
```

## ⚠️ Requisitos Importantes

**Ambas as opções requerem:**
- ✅ Vault com HTTPS (HTTP não é suportado)
- ✅ KV v2 secret engine habilitado
- ✅ Kubernetes auth method configurado
- ✅ Policies e roles criados no Vault

## 📚 Recursos Adicionais

- [Redis Enterprise Vault Integration](https://redis.io/blog/kubernetes-secret/)
- [Vault Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide)

## 🤝 Contribuindo

Este é um projeto de referência. Adapte às suas necessidades específicas.

