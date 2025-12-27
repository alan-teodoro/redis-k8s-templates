# Google Cloud Storage Backup for Redis Enterprise

Complete guide for configuring automated backups to Google Cloud Storage (GCS).

**Best for:** GKE deployments, Google Cloud environments

---

## 📋 Overview

This guide covers:
- GCS bucket creation and configuration
- Service Account permissions (JSON key or Workload Identity)
- Database backup configuration
- Restore procedures
- Troubleshooting

---

## 🎯 Prerequisites

### Google Cloud Resources

- **GCS Bucket** for storing backups
- **Service Account** with GCS access (Option 1)
  - OR **Workload Identity** (Option 2 - recommended for GKE)

### Kubernetes Resources

- Redis Enterprise Cluster (REC) deployed
- Redis Enterprise Operator installed
- Namespace: `redis-enterprise`

---

## 🚀 Quick Start

### Step 1: Create GCS Bucket

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=redis-backups-$(date +%s)
export REGION=us-central1

# Create bucket
gcloud storage buckets create gs://${BUCKET_NAME} \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --uniform-bucket-level-access

# Enable versioning (recommended)
gcloud storage buckets update gs://${BUCKET_NAME} \
  --versioning

# Set lifecycle policy to delete old backups (optional)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"age": 90}
    }]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

### Step 2: Configure Service Account Permissions

**Choose one option:**

#### Option 1: Service Account with JSON Key (Simple)

```bash
# Create service account
gcloud iam service-accounts create redis-backup-sa \
  --display-name="Redis Enterprise Backup Service Account"

# Grant Storage Object Admin role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:redis-backup-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin" \
  --condition="resource.name.startsWith('projects/_/buckets/${BUCKET_NAME}')"

# Create JSON key
gcloud iam service-accounts keys create redis-backup-key.json \
  --iam-account=redis-backup-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

#### Option 2: Workload Identity (Recommended for GKE)

See [workload-identity.md](workload-identity.md) for detailed setup.

### Step 3: Create Kubernetes Secret

**For Option 1 (JSON Key):**

```bash
kubectl create secret generic gcs-backup-credentials \
  --namespace redis-enterprise \
  --from-file=GOOGLE_APPLICATION_CREDENTIALS=redis-backup-key.json
```

**For Option 2 (Workload Identity):**

No secret needed - Workload Identity provides credentials automatically.

### Step 4: Deploy Database with Backup

```bash
# Edit 02-redb-gcs-backup.yaml with your bucket name
kubectl apply -f 02-redb-gcs-backup.yaml
```

### Step 5: Verify Backup Configuration

```bash
# Check database status
kubectl get redb test-db -n redis-enterprise

# Check backup configuration
kubectl get redb test-db -n redis-enterprise -o yaml | grep -A15 backup

# List backups in GCS
gcloud storage ls gs://${BUCKET_NAME}/production/test-db/
```

---

## 📊 Backup Configuration Options

### Interval-Based Backups

```yaml
spec:
  backup:
    interval: 24  # Every 24 hours
    gcs:
      gcsSecretName: gcs-backup-credentials
      bucketName: redis-backups
      subdir: production/test-db
```

### Time-Based Backups

```yaml
spec:
  backup:
    time: "03:00"  # 3 AM UTC daily
    gcs:
      gcsSecretName: gcs-backup-credentials
      bucketName: redis-backups
      subdir: production/test-db
```

---

## 🔄 Restore Procedure

See [03-restore-from-gcs.yaml](03-restore-from-gcs.yaml) for complete restore configuration.

### Restore to New Database

```bash
# Apply restore configuration
kubectl apply -f 03-restore-from-gcs.yaml
```

### List Available Backups

```bash
# List backups in GCS
gcloud storage ls gs://${BUCKET_NAME}/production/test-db/

# Download backup locally (optional)
gcloud storage cp gs://${BUCKET_NAME}/production/test-db/backup-2024-01-15-030000.rdb ./
```

---

## 🔍 Troubleshooting

### Access Denied Errors

**Verify Service Account permissions:**
```bash
# Test GCS access
gcloud storage ls gs://${BUCKET_NAME}/
```

**Check secret exists:**
```bash
kubectl get secret gcs-backup-credentials -n redis-enterprise
```

### Backup Not Running

**Check operator logs:**
```bash
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=100 | grep -i backup
```

**Check database status:**
```bash
kubectl describe redb test-db -n redis-enterprise
```

---

## 📖 Best Practices

### Security

1. **Use Workload Identity** instead of JSON keys (for GKE)
2. **Enable bucket encryption** (Google-managed or customer-managed keys)
3. **Enable bucket versioning** (protect against accidental deletion)
4. **Use separate buckets** for different environments
5. **Implement Object Lifecycle Management** (delete old backups)

### Reliability

1. **Test restore procedure regularly**
2. **Monitor backup success** with Cloud Monitoring
3. **Use multi-region buckets** for critical data
4. **Document backup locations** in runbooks

### Cost Optimization

1. **Use Standard storage class** for frequent access
2. **Use Nearline/Coldline** for long-term retention
3. **Set lifecycle policies** to transition to cheaper storage classes
4. **Monitor storage costs** with Cloud Billing

---

## 📚 Additional Resources

- [Redis Enterprise Backup Documentation](https://docs.redis.com/latest/rs/databases/import-export/schedule-backups/)
- [GCS Best Practices](https://cloud.google.com/storage/docs/best-practices)
- [Workload Identity Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

