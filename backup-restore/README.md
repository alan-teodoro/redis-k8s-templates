# Backup & Restore for Redis Enterprise on Kubernetes

Complete backup and restore solutions for Redis Enterprise databases on Kubernetes.

**Platform-agnostic:** Works on EKS, GKE, AKS, OpenShift, and vanilla Kubernetes.

---

## 📋 Overview

Redis Enterprise supports automated backups to cloud object storage:
- **AWS S3** - Amazon Simple Storage Service
- **Google Cloud Storage (GCS)** - Google Cloud object storage
- **Azure Blob Storage** - Microsoft Azure object storage
- **SFTP** - Any SFTP server

### Backup Types

1. **Scheduled Backups** - Automatic backups at regular intervals
2. **Manual Backups** - On-demand backups via API
3. **Snapshot Backups** - Point-in-time snapshots

### What Gets Backed Up

- Database data (RDB snapshot)
- Database configuration
- Module data (if using RedisJSON, RediSearch, etc.)

### What Does NOT Get Backed Up

- Cluster configuration (REC)
- Operator configuration
- Kubernetes resources (use GitOps for this)

---

## 📁 Structure

```
backup-restore/
├── README.md                           # This file
├── s3/                                 # AWS S3 backups
│   ├── README.md                       # S3 setup guide
│   ├── 01-s3-credentials-secret.yaml   # S3 credentials
│   ├── 02-redb-s3-backup.yaml          # REDB with S3 backup
│   ├── 03-restore-from-s3.yaml         # Restore procedure
│   └── iam-policy.json                 # IAM policy for S3 access
├── gcs/                                # Google Cloud Storage
│   ├── README.md                       # GCS setup guide
│   ├── 01-gcs-credentials-secret.yaml  # GCS credentials
│   ├── 02-redb-gcs-backup.yaml         # REDB with GCS backup
│   ├── 03-restore-from-gcs.yaml        # Restore procedure
│   └── workload-identity.md            # Workload Identity setup
├── azure-blob/                         # Azure Blob Storage
│   ├── README.md                       # Azure setup guide
│   ├── 01-azure-credentials-secret.yaml # Azure credentials
│   ├── 02-redb-azure-backup.yaml       # REDB with Azure backup
│   ├── 03-restore-from-azure.yaml      # Restore procedure
│   └── managed-identity.md             # Managed Identity setup
├── sftp/                               # SFTP backups
│   ├── README.md                       # SFTP setup guide
│   ├── 01-sftp-credentials-secret.yaml # SFTP credentials
│   └── 02-redb-sftp-backup.yaml        # REDB with SFTP backup
└── scheduled-backups/                  # Advanced scheduling
    ├── README.md                       # Scheduling guide
    └── backup-cronjob.yaml             # CronJob for manual backups
```

---

## 🚀 Quick Start

### Choose Your Storage Provider

| Provider | Best For | Guide |
|----------|----------|-------|
| **AWS S3** | EKS deployments | [s3/README.md](s3/README.md) |
| **Google Cloud Storage** | GKE deployments | [gcs/README.md](gcs/README.md) |
| **Azure Blob Storage** | AKS deployments | [azure-blob/README.md](azure-blob/README.md) |
| **SFTP** | On-premises, air-gapped | [sftp/README.md](sftp/README.md) |

### Basic Backup Configuration

All backup configurations follow the same pattern:

1. **Create credentials secret** (cloud provider credentials)
2. **Configure REDB with backup** (schedule, location, retention)
3. **Verify backups** (check backup status)
4. **Test restore** (restore to new database)

---

## 📊 Backup Configuration Options

### Common Settings (All Providers)

```yaml
spec:
  backup:
    interval: 24              # Backup interval in hours (1-24)
    # OR
    # time: "03:00"           # Specific time (HH:MM format, UTC)
```

### Retention Policy

Redis Enterprise automatically manages backup retention:
- Keeps last 7 daily backups
- Keeps last 4 weekly backups
- Keeps last 12 monthly backups

---

## 🔐 Security Best Practices

### Credentials Management

**Option 1: Kubernetes Secrets** (Basic)
```bash
kubectl create secret generic s3-backup-credentials \
  --namespace redis-enterprise \
  --from-literal=AWS_ACCESS_KEY_ID=<key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret>
```

**Option 2: External Secrets Operator** (Recommended)
- Use AWS Secrets Manager, Azure Key Vault, or GCP Secret Manager
- See [../integrations/external-secrets/](../integrations/external-secrets/)

**Option 3: HashiCorp Vault** (Enterprise)
- Centralized secret management
- See [../integrations/vault/](../integrations/vault/)

### Encryption

- **In-transit:** All cloud providers use HTTPS/TLS
- **At-rest:** Enable server-side encryption on storage bucket
  - S3: SSE-S3, SSE-KMS, or SSE-C
  - GCS: Google-managed or customer-managed keys
  - Azure: Microsoft-managed or customer-managed keys

---

## 🧪 Testing Backup & Restore

### Verify Backup Configuration

```bash
# Check database status
kubectl get redb <db-name> -n redis-enterprise -o yaml | grep -A10 backup

# Check backup status via API
REC_USER=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d)
REC_PASS=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

curl -k -u $REC_USER:$REC_PASS \
  https://<rec-api-url>:9443/v1/bdbs/<bdb-id>/backup
```

### Test Restore

See provider-specific guides for restore procedures:
- [S3 Restore](s3/README.md#restore-procedure)
- [GCS Restore](gcs/README.md#restore-procedure)
- [Azure Restore](azure-blob/README.md#restore-procedure)

---

## 📖 Next Steps

1. **Choose storage provider** based on your platform
2. **Follow provider-specific guide** for detailed setup
3. **Configure scheduled backups** for all production databases
4. **Test restore procedure** before going to production
5. **Document backup locations** for disaster recovery

---

## 🔍 Troubleshooting

See provider-specific troubleshooting sections:
- [S3 Troubleshooting](s3/README.md#troubleshooting)
- [GCS Troubleshooting](gcs/README.md#troubleshooting)
- [Azure Troubleshooting](azure-blob/README.md#troubleshooting)

