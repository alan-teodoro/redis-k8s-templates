# AWS S3 Backup for Redis Enterprise

Complete guide for configuring automated backups to Amazon S3.

**Best for:** EKS deployments, AWS environments

---

## 📋 Overview

This guide covers:
- S3 bucket creation and configuration
- IAM permissions (access keys or IRSA)
- Database backup configuration
- Restore procedures
- Troubleshooting

---

## 🎯 Prerequisites

### AWS Resources

- **S3 Bucket** for storing backups
- **IAM User** with S3 access (Option 1)
  - OR **IAM Role for Service Account (IRSA)** (Option 2 - recommended for EKS)

### Kubernetes Resources

- Redis Enterprise Cluster (REC) deployed
- Redis Enterprise Operator installed
- Namespace: `redis-enterprise`

---

## 🚀 Quick Start

### Step 1: Create S3 Bucket

```bash
# Set variables
export AWS_REGION=us-east-1
export BUCKET_NAME=redis-backups-$(date +%s)

# Create bucket
aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Enable encryption (recommended)
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access (security best practice)
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 2: Configure IAM Permissions

**Choose one option:**

#### Option 1: IAM User with Access Keys (Simple)

Create IAM policy (see [iam-policy.json](iam-policy.json)):

```bash
# Create IAM policy
aws iam create-policy \
  --policy-name RedisEnterpriseS3BackupPolicy \
  --policy-document file://iam-policy.json

# Create IAM user
aws iam create-user --user-name redis-backup-user

# Attach policy to user
aws iam attach-user-policy \
  --user-name redis-backup-user \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/RedisEnterpriseS3BackupPolicy

# Create access keys
aws iam create-access-key --user-name redis-backup-user
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

#### Option 2: IRSA (Recommended for EKS)

See [IRSA Setup Guide](../../platforms/eks/iam/README.md) for detailed instructions.

### Step 3: Create Kubernetes Secret

**For Option 1 (Access Keys):**

```bash
kubectl create secret generic s3-backup-credentials \
  --namespace redis-enterprise \
  --from-literal=AWS_ACCESS_KEY_ID=<your-access-key-id> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
```

**For Option 2 (IRSA):**

No secret needed - IRSA provides credentials automatically.

### Step 4: Deploy Database with Backup

Apply the REDB configuration:

```bash
# Edit 02-redb-s3-backup.yaml with your bucket name and region
kubectl apply -f 02-redb-s3-backup.yaml
```

### Step 5: Verify Backup Configuration

```bash
# Check database status
kubectl get redb test-db -n redis-enterprise

# Check backup configuration
kubectl get redb test-db -n redis-enterprise -o yaml | grep -A15 backup
```

---

## 📊 Backup Configuration Options

### Interval-Based Backups

Backup every N hours (1-24):

```yaml
spec:
  backup:
    interval: 24  # Every 24 hours
    s3:
      awsSecretName: s3-backup-credentials
      bucketName: redis-backups
      subdir: production/test-db
```

### Time-Based Backups

Backup at specific time (UTC):

```yaml
spec:
  backup:
    time: "03:00"  # 3 AM UTC daily
    s3:
      awsSecretName: s3-backup-credentials
      bucketName: redis-backups
      subdir: production/test-db
```

### Advanced Options

```yaml
spec:
  backup:
    interval: 12
    s3:
      awsSecretName: s3-backup-credentials
      bucketName: redis-backups
      subdir: production/test-db
      # Optional: Specify region (auto-detected if not specified)
      # awsRegion: us-east-1
```

---

## 🔄 Restore Procedure

See [03-restore-from-s3.yaml](03-restore-from-s3.yaml) for complete restore configuration.

### Restore to New Database

```bash
# Apply restore configuration
kubectl apply -f 03-restore-from-s3.yaml
```

### Restore to Existing Database

**⚠️ WARNING:** This will overwrite existing data!

```bash
# Scale down applications using the database
kubectl scale deployment <app-name> --replicas=0

# Delete existing database
kubectl delete redb test-db -n redis-enterprise

# Wait for deletion
kubectl wait --for=delete redb/test-db -n redis-enterprise --timeout=300s

# Apply restore configuration
kubectl apply -f 03-restore-from-s3.yaml

# Wait for database to be ready
kubectl wait --for=condition=Ready redb/test-db -n redis-enterprise --timeout=300s

# Scale up applications
kubectl scale deployment <app-name> --replicas=<original-count>
```

---

## 🔍 Troubleshooting

### Backup Not Running

**Check database status:**
```bash
kubectl describe redb test-db -n redis-enterprise
```

**Check operator logs:**
```bash
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=100 | grep -i backup
```

**Common issues:**
- Invalid S3 credentials
- Bucket does not exist
- Insufficient IAM permissions
- Network connectivity issues

### Access Denied Errors

**Symptom:** Backup fails with "Access Denied" error

**Solutions:**

1. **Verify IAM permissions:**
```bash
# Test S3 access with AWS CLI
aws s3 ls s3://${BUCKET_NAME}/ --region ${AWS_REGION}
```

2. **Check secret exists:**
```bash
kubectl get secret s3-backup-credentials -n redis-enterprise
```

3. **Verify secret content:**
```bash
kubectl get secret s3-backup-credentials -n redis-enterprise -o yaml
```

4. **For IRSA:** Verify service account annotation:
```bash
kubectl get sa redis-enterprise-operator -n redis-enterprise -o yaml | grep eks.amazonaws.com
```

### Backup Files Not Appearing in S3

**Check backup status via API:**
```bash
REC_USER=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d)
REC_PASS=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

# Get database ID
kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databaseUID}'

# Check backup status
curl -k -u $REC_USER:$REC_PASS \
  https://rec.redis-enterprise.svc.cluster.local:9443/v1/bdbs/<bdb-id>/backup
```

**List backups in S3:**
```bash
aws s3 ls s3://${BUCKET_NAME}/production/test-db/ --recursive
```

### Restore Fails

**Common issues:**

1. **Backup file not found:**
   - Verify backup exists in S3
   - Check `subdir` path matches backup location

2. **Incompatible Redis version:**
   - Backup from newer version cannot restore to older version
   - Check Redis Enterprise version compatibility

3. **Insufficient memory:**
   - Ensure new database has enough memory for restored data
   - Check `memorySize` in REDB spec

---

## 📖 Best Practices

### Security

1. **Use IRSA instead of access keys** (for EKS)
2. **Enable S3 bucket encryption** (SSE-S3 or SSE-KMS)
3. **Enable S3 bucket versioning** (protect against accidental deletion)
4. **Use separate buckets** for different environments (dev/staging/prod)
5. **Implement bucket lifecycle policies** (archive old backups to Glacier)

### Reliability

1. **Test restore procedure regularly** (monthly recommended)
2. **Monitor backup success** (set up alerts)
3. **Use cross-region replication** for critical data
4. **Document backup locations** in runbooks

### Cost Optimization

1. **Use S3 Intelligent-Tiering** for automatic cost optimization
2. **Set lifecycle policies** to delete old backups
3. **Use compression** (enabled by default in Redis Enterprise)
4. **Monitor S3 storage costs** with AWS Cost Explorer

---

## 📚 Additional Resources

- [Redis Enterprise Backup Documentation](https://docs.redis.com/latest/rs/databases/import-export/schedule-backups/)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [EKS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

