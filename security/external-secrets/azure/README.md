# Azure Key Vault Integration

Integrate Redis Enterprise with Azure Key Vault using External Secrets Operator.

## 📋 Overview

Azure Key Vault provides centralized secret management with automatic rotation, audit logging, and fine-grained access control.

**Benefits:**
- ✅ Automatic secret rotation
- ✅ Azure Monitor audit logging
- ✅ Azure RBAC access control
- ✅ Encryption at rest
- ✅ No secrets in Git

## ✅ Prerequisites

1. **Azure AKS Cluster** with Managed Identity enabled
2. **External Secrets Operator** installed
3. **Azure CLI** configured
4. **kubectl** access to cluster

## 🔧 Setup

### Step 1: Create Azure Key Vault

```bash
# Variables
RESOURCE_GROUP="redis-enterprise-rg"
KEY_VAULT_NAME="redis-enterprise-kv"
LOCATION="eastus"

# Create resource group (if not exists)
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Key Vault
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true

# Get Key Vault ID
KEY_VAULT_ID=$(az keyvault show --name $KEY_VAULT_NAME --query id -o tsv)
echo "Key Vault ID: $KEY_VAULT_ID"
```

### Step 2: Create Secrets in Azure Key Vault

```bash
# Create admin password secret
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name redis-admin-password \
  --value "RedisAdmin123!"

# Create database password secret
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name redis-database-password \
  --value "RedisDB123!"

# List secrets
az keyvault secret list --vault-name $KEY_VAULT_NAME -o table
```

### Step 3: Enable Managed Identity on AKS

```bash
# Get AKS cluster name
CLUSTER_NAME="your-aks-cluster"

# Enable Managed Identity (if not already enabled)
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-managed-identity

# Get kubelet identity
KUBELET_IDENTITY=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query identityProfile.kubeletidentity.clientId -o tsv)

echo "Kubelet Identity: $KUBELET_IDENTITY"
```

### Step 4: Grant Key Vault Access to Managed Identity

```bash
# Assign Key Vault Secrets User role to kubelet identity
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $KUBELET_IDENTITY \
  --scope $KEY_VAULT_ID
```

### Step 5: Create SecretStore

See: [01-secret-store.yaml](01-secret-store.yaml)

```bash
# Update YAML with your Key Vault name
# Then apply:
kubectl apply -f 01-secret-store.yaml

# Verify
kubectl get secretstore -n redis-enterprise
```

### Step 6: Create ExternalSecrets

See: [02-external-secret-admin.yaml](02-external-secret-admin.yaml)
See: [03-external-secret-database.yaml](03-external-secret-database.yaml)

```bash
kubectl apply -f 02-external-secret-admin.yaml
kubectl apply -f 03-external-secret-database.yaml

# Verify
kubectl get externalsecret -n redis-enterprise
kubectl get secret rec-admin-password -n redis-enterprise
```

## 🚀 Usage

See: [04-rec-external-secrets.yaml](04-rec-external-secrets.yaml)
See: [05-redb-external-secrets.yaml](05-redb-external-secrets.yaml)

## 🔄 Secret Rotation

```bash
# Update secret in Azure Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name redis-admin-password \
  --value "NewRedisAdmin456!"

# ESO will automatically sync within refreshInterval
```

## 🔍 Troubleshooting

### Common Issues

1. **Access denied errors**
   - Verify Managed Identity has Key Vault Secrets User role
   - Check Key Vault name in SecretStore
   - Verify RBAC is enabled on Key Vault

2. **Secret not found**
   - Verify secret exists in Key Vault
   - Check secret name matches ExternalSecret spec

## 📚 References

- Azure Key Vault: https://azure.microsoft.com/en-us/services/key-vault/
- AKS Managed Identity: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity
- External Secrets Azure Provider: https://external-secrets.io/latest/provider/azure-key-vault/

