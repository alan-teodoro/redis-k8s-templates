# External Secrets Operator for Redis Enterprise

Integrate Redis Enterprise with cloud-native secret management using External Secrets Operator (ESO).

## 📋 Table of Contents

- [Overview](#overview)
- [Why External Secrets Operator?](#why-external-secrets-operator)
- [Architecture](#architecture)
- [Supported Providers](#supported-providers)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Best Practices](#best-practices)

---

## 🎯 Overview

External Secrets Operator (ESO) synchronizes secrets from external secret management systems (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, HashiCorp Vault) into Kubernetes secrets.

**Benefits:**
- ✅ Centralized secret management
- ✅ Cloud-native integration
- ✅ Automatic secret rotation
- ✅ Audit logging
- ✅ Fine-grained access control
- ✅ No secrets in Git

---

## 🤔 Why External Secrets Operator?

### Without ESO (Manual Secret Management)

```
┌─────────────────────────────────────────────────────────┐
│  Manual Secret Management                               │
│                                                          │
│  1. Create secret in cloud provider (AWS/Azure/GCP)     │
│  2. Manually copy secret value                          │
│  3. Create Kubernetes secret with copied value          │
│  4. Update REC/REDB to use secret                       │
│  5. Monitor secret expiry                               │
│  6. Manually rotate secret in cloud provider            │
│  7. Manually update Kubernetes secret                   │
│  8. Restart pods to load new secret                     │
│                                                          │
│  ❌ Manual intervention required                        │
│  ❌ Secrets in Git (security risk)                      │
│  ❌ No audit trail                                      │
│  ❌ Difficult to rotate                                 │
└─────────────────────────────────────────────────────────┘
```

### With ESO (Automated Secret Management)

```
┌─────────────────────────────────────────────────────────┐
│  Automated Secret Management                            │
│                                                          │
│  1. Create secret in cloud provider (AWS/Azure/GCP)     │
│  2. Define ExternalSecret CRD                           │
│  3. ESO fetches secret from cloud provider              │
│  4. ESO creates Kubernetes secret automatically         │
│  5. Configure REC/REDB to use secret                    │
│  6. ESO monitors secret changes                         │
│  7. ESO auto-updates Kubernetes secret on change        │
│  8. Operator detects change and reloads                 │
│                                                          │
│  ✅ Fully automated                                     │
│  ✅ No secrets in Git                                   │
│  ✅ Full audit trail                                    │
│  ✅ Automatic rotation                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  Cloud Secret Manager                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  AWS Secrets   │  │  Azure Key     │  │  GCP Secret    │ │
│  │   Manager      │  │    Vault       │  │   Manager      │ │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘ │
└───────────┼──────────────────┼──────────────────┼────────────┘
            │                  │                  │
            │                  │                  │
            ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│              External Secrets Operator (ESO)                  │
│                                                               │
│  ┌────────────────┐         ┌────────────────┐              │
│  │ SecretStore    │────────►│ ExternalSecret │              │
│  │    (CRD)       │         │     (CRD)      │              │
│  └────────────────┘         └────────┬───────┘              │
│                                      │                       │
│                                      ▼                       │
│                          ┌────────────────────┐             │
│                          │   Secret (K8s)     │             │
│                          │  (auto-created)    │             │
│                          └────────┬───────────┘             │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │ Redis Enterprise Cluster │
                    │        (REC)             │
                    └──────────────────────────┘
```

---

## 🔌 Supported Providers

External Secrets Operator supports multiple secret management providers:

| Provider | Authentication | Documentation |
|----------|----------------|---------------|
| **AWS Secrets Manager** | IRSA (IAM Roles for Service Accounts) | [aws/README.md](aws/README.md) |
| **Azure Key Vault** | Managed Identity / Service Principal | [azure/README.md](azure/README.md) |
| **GCP Secret Manager** | Workload Identity / Service Account | [gcp/README.md](gcp/README.md) |
| **HashiCorp Vault** | Kubernetes Auth / Token | See [integrations/vault](../../integrations/vault/README.md) |

---

## 📦 Installation

### Step 1: Install External Secrets Operator

```bash
# Add External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true

# Verify installation
kubectl get pods -n external-secrets-system

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# external-secrets-xxxxxxxxxx-xxxxx                   1/1     Running   0          1m
# external-secrets-cert-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
# external-secrets-webhook-xxxxxxxxxx-xxxxx           1/1     Running   0          1m
```

### Step 2: Verify Installation

```bash
# Check External Secrets CRDs
kubectl get crd | grep external-secrets

# Expected CRDs:
# clusterexternalsecrets.external-secrets.io
# clustersecretstores.external-secrets.io
# externalsecrets.external-secrets.io
# secretstores.external-secrets.io

# Check External Secrets version
kubectl get deployment -n external-secrets-system external-secrets \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 🚀 Quick Start

### Choose Your Cloud Provider

1. **AWS Secrets Manager** - [aws/README.md](aws/README.md)
   - Best for: AWS EKS clusters
   - Authentication: IRSA (IAM Roles for Service Accounts)
   - Setup time: ~15 minutes

2. **Azure Key Vault** - [azure/README.md](azure/README.md)
   - Best for: Azure AKS clusters
   - Authentication: Managed Identity
   - Setup time: ~15 minutes

3. **GCP Secret Manager** - [gcp/README.md](gcp/README.md)
   - Best for: GCP GKE clusters
   - Authentication: Workload Identity
   - Setup time: ~15 minutes

---

## ✅ Best Practices

### 1. **Use Cloud-Native Authentication**
- ✅ AWS: Use IRSA instead of access keys
- ✅ Azure: Use Managed Identity instead of service principals
- ✅ GCP: Use Workload Identity instead of service account keys

### 2. **Implement Least Privilege**
- ✅ Grant only required permissions
- ✅ Use separate secrets for different environments
- ✅ Restrict secret access by namespace

### 3. **Enable Secret Rotation**
- ✅ Configure automatic secret rotation in cloud provider
- ✅ Set refreshInterval in ExternalSecret (e.g., 1h)
- ✅ Monitor rotation events

### 4. **Monitor Secret Sync**
- ✅ Set up alerts for sync failures
- ✅ Monitor ExternalSecret status
- ✅ Track secret age

### 5. **Secure Secret Store Credentials**
- ✅ Use Kubernetes RBAC to restrict access
- ✅ Store credentials in separate namespace
- ✅ Audit secret access

### 6. **Test Secret Rotation**
- ✅ Manually rotate secrets to test process
- ✅ Verify applications reload secrets
- ✅ Document rollback procedure

---

## 📚 Related Documentation

- [AWS Secrets Manager Integration](aws/README.md)
- [Azure Key Vault Integration](azure/README.md)
- [GCP Secret Manager Integration](gcp/README.md)
- [HashiCorp Vault Integration](../../integrations/vault/README.md)
- [TLS Certificates](../tls-certificates/README.md)

---

## 🔗 References

- External Secrets Operator: https://external-secrets.io/
- AWS Secrets Manager: https://aws.amazon.com/secrets-manager/
- Azure Key Vault: https://azure.microsoft.com/en-us/services/key-vault/
- GCP Secret Manager: https://cloud.google.com/secret-manager

