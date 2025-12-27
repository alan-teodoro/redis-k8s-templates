# Azure Blob Storage Backup for Redis Enterprise

Complete guide for configuring automated backups to Azure Blob Storage.

**Best for:** AKS deployments, Azure environments

---

## 📋 Overview

This guide covers:
- Azure Storage Account and container creation
- Access configuration (Storage Account Key or Managed Identity)
- Database backup configuration
- Restore procedures
- Troubleshooting

---

## 🎯 Prerequisites

### Azure Resources

- **Storage Account** with Blob Storage
- **Blob Container** for storing backups
- **Storage Account Key** (Option 1)
  - OR **Managed Identity** (Option 2 - recommended for AKS)

### Kubernetes Resources

- Redis Enterprise Cluster (REC) deployed
- Redis Enterprise Operator installed
- Namespace: `redis-enterprise`

---

## 🚀 Quick Start

### Step 1: Create Storage Account and Container

```bash
# Set variables
export RESOURCE_GROUP=redis-rg
export STORAGE_ACCOUNT=redisbackups$(date +%s | cut -c 6-10)
export CONTAINER_NAME=redis-backups
export LOCATION=eastus

# Create resource group (if not exists)
az group create \
  --name ${RESOURCE_GROUP} \
  --location ${LOCATION}

# Create storage account
az storage account create \
  --name ${STORAGE_ACCOUNT} \
  --resource-group ${RESOURCE_GROUP} \
  --location ${LOCATION} \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2

# Create blob container
az storage container create \
  --name ${CONTAINER_NAME} \
  --account-name ${STORAGE_ACCOUNT} \
  --auth-mode login
```

### Step 2: Configure Access

**Choose one option:**

#### Option 1: Storage Account Key (Simple)

```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group ${RESOURCE_GROUP} \
  --account-name ${STORAGE_ACCOUNT} \
  --query '[0].value' -o tsv)

echo "Storage Account: ${STORAGE_ACCOUNT}"
echo "Storage Key: ${STORAGE_KEY}"
```

#### Option 2: Managed Identity (Recommended for AKS)

See [managed-identity.md](managed-identity.md) for detailed setup.

### Step 3: Create Kubernetes Secret

**For Option 1 (Storage Account Key):**

```bash
kubectl create secret generic azure-backup-credentials \
  --namespace redis-enterprise \
  --from-literal=AZURE_ACCOUNT_NAME=${STORAGE_ACCOUNT} \
  --from-literal=AZURE_ACCOUNT_KEY=${STORAGE_KEY}
```

**For Option 2 (Managed Identity):**

No secret needed - Managed Identity provides credentials automatically.

### Step 4: Deploy Database with Backup

```bash
# Edit 02-redb-azure-backup.yaml with your storage account and container
kubectl apply -f 02-redb-azure-backup.yaml
```

### Step 5: Verify Backup Configuration

```bash
# Check database status
kubectl get redb test-db -n redis-enterprise

# List backups in Azure
az storage blob list \
  --container-name ${CONTAINER_NAME} \
  --account-name ${STORAGE_ACCOUNT} \
  --prefix production/test-db/ \
  --auth-mode login \
  --output table
```

---

## 📊 Backup Configuration Options

### Interval-Based Backups

```yaml
spec:
  backup:
    interval: 24
    abs:
      absSecretName: azure-backup-credentials
      container: redis-backups
      subdir: production/test-db
```

### Time-Based Backups

```yaml
spec:
  backup:
    time: "03:00"
    abs:
      absSecretName: azure-backup-credentials
      container: redis-backups
      subdir: production/test-db
```

---

## 🔄 Restore Procedure

See [03-restore-from-azure.yaml](03-restore-from-azure.yaml) for complete restore configuration.

### List Available Backups

```bash
az storage blob list \
  --container-name ${CONTAINER_NAME} \
  --account-name ${STORAGE_ACCOUNT} \
  --prefix production/test-db/ \
  --auth-mode login \
  --output table
```

---

## 🔍 Troubleshooting

### Access Denied Errors

**Verify storage account key:**
```bash
az storage account keys list \
  --resource-group ${RESOURCE_GROUP} \
  --account-name ${STORAGE_ACCOUNT}
```

**Check secret:**
```bash
kubectl get secret azure-backup-credentials -n redis-enterprise -o yaml
```

### Backup Not Running

**Check operator logs:**
```bash
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=100 | grep -i backup
```

---

## 📖 Best Practices

### Security

1. **Use Managed Identity** instead of storage keys (for AKS)
2. **Enable storage encryption** (enabled by default)
3. **Use private endpoints** for storage account
4. **Rotate storage keys regularly**
5. **Use separate storage accounts** for different environments

### Reliability

1. **Enable soft delete** on blob storage
2. **Test restore procedure regularly**
3. **Use geo-redundant storage (GRS)** for critical data
4. **Monitor backup success** with Azure Monitor

### Cost Optimization

1. **Use Cool or Archive tier** for long-term retention
2. **Set lifecycle management policies**
3. **Monitor storage costs** with Azure Cost Management

---

## 📚 Additional Resources

- [Redis Enterprise Backup Documentation](https://docs.redis.com/latest/rs/databases/import-export/schedule-backups/)
- [Azure Blob Storage Best Practices](https://docs.microsoft.com/azure/storage/blobs/storage-blobs-introduction)
- [AKS Managed Identity Documentation](https://docs.microsoft.com/azure/aks/use-managed-identity)

