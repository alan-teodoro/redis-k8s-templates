# Managed Identity Setup for Azure Blob Storage Backups

Guide for configuring Managed Identity to access Azure Blob Storage without storing credentials in Kubernetes.

**Recommended for:** AKS deployments

---

## Overview

Managed Identity allows AKS pods to authenticate to Azure services without storing credentials.

**Benefits:**
- No credentials stored in Kubernetes
- Automatic credential rotation
- Fine-grained RBAC permissions
- Better security posture

---

## Prerequisites

- AKS cluster with Managed Identity enabled
- Azure Storage Account and container created
- `az` CLI configured

---

## Setup Steps

### Step 1: Enable Managed Identity on AKS

```bash
# For existing cluster (if not already enabled)
az aks update \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --enable-managed-identity

# For new cluster (enabled by default)
az aks create \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --enable-managed-identity
```

### Step 2: Create User-Assigned Managed Identity

```bash
# Set variables
export RESOURCE_GROUP=redis-rg
export IDENTITY_NAME=redis-backup-identity
export STORAGE_ACCOUNT=redisbackups12345
export CONTAINER_NAME=redis-backups

# Create managed identity
az identity create \
  --resource-group ${RESOURCE_GROUP} \
  --name ${IDENTITY_NAME}

# Get identity details
IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${IDENTITY_NAME} \
  --query clientId -o tsv)

IDENTITY_RESOURCE_ID=$(az identity show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${IDENTITY_NAME} \
  --query id -o tsv)
```

### Step 3: Grant Storage Permissions

```bash
# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --name ${STORAGE_ACCOUNT} \
  --resource-group ${RESOURCE_GROUP} \
  --query id -o tsv)

# Assign Storage Blob Data Contributor role
az role assignment create \
  --assignee ${IDENTITY_CLIENT_ID} \
  --role "Storage Blob Data Contributor" \
  --scope ${STORAGE_ID}
```

### Step 4: Configure AKS Pod Identity

```bash
# Get AKS node resource group
NODE_RESOURCE_GROUP=$(az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name <cluster-name> \
  --query nodeResourceGroup -o tsv)

# Assign Managed Identity Operator role to AKS
AKS_IDENTITY=$(az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name <cluster-name> \
  --query identityProfile.kubeletidentity.clientId -o tsv)

az role assignment create \
  --assignee ${AKS_IDENTITY} \
  --role "Managed Identity Operator" \
  --scope ${IDENTITY_RESOURCE_ID}
```

### Step 5: Create Azure Identity and Binding

```yaml
# azure-identity.yaml
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentity
metadata:
  name: redis-backup-identity
  namespace: redis-enterprise
spec:
  type: 0  # User-assigned identity
  resourceID: <IDENTITY_RESOURCE_ID>
  clientID: <IDENTITY_CLIENT_ID>
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: redis-backup-identity-binding
  namespace: redis-enterprise
spec:
  azureIdentity: redis-backup-identity
  selector: redis-backup
```

Apply:
```bash
kubectl apply -f azure-identity.yaml
```

### Step 6: Update Operator Deployment

Add label to operator pods:

```bash
kubectl patch deployment redis-enterprise-operator \
  --namespace redis-enterprise \
  --type merge \
  --patch '{"spec":{"template":{"metadata":{"labels":{"aadpodidbinding":"redis-backup"}}}}}'
```

### Step 7: Deploy Database with Backup

**Important:** Remove `absSecretName` when using Managed Identity.

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: test-db
  namespace: redis-enterprise
spec:
  name: test-db
  memorySize: 1GB
  databasePort: 12000
  
  backup:
    interval: 24
    abs:
      # NO absSecretName - Managed Identity provides credentials
      container: redis-backups
      subdir: production/test-db
```

---

## Verification

### Test Managed Identity

```bash
# Create test pod with identity label
kubectl run azure-cli-test \
  --image=mcr.microsoft.com/azure-cli \
  --labels=aadpodidbinding=redis-backup \
  --namespace=redis-enterprise \
  -it --rm -- bash

# Inside pod, test storage access
az login --identity
az storage blob list \
  --container-name redis-backups \
  --account-name ${STORAGE_ACCOUNT} \
  --auth-mode login
```

---

## Troubleshooting

### "Permission Denied" Errors

**Check role assignment:**
```bash
az role assignment list \
  --assignee ${IDENTITY_CLIENT_ID} \
  --scope ${STORAGE_ID}
```

### Pod Identity Not Working

**Check AAD Pod Identity is installed:**
```bash
kubectl get pods -n kube-system | grep aad-pod-identity
```

If not installed, install AAD Pod Identity:
```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```

---

## Best Practices

1. **Use separate identities** for different environments
2. **Grant minimal permissions** (only required storage accounts)
3. **Monitor role assignments** with Azure Activity Log
4. **Document identity mappings** in runbooks

---

## Additional Resources

- [AKS Managed Identity Documentation](https://docs.microsoft.com/azure/aks/use-managed-identity)
- [AAD Pod Identity](https://azure.github.io/aad-pod-identity/)
- [Azure RBAC Best Practices](https://docs.microsoft.com/azure/role-based-access-control/best-practices)

