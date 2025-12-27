# Workload Identity Setup for GCS Backups

Guide for configuring Workload Identity to access GCS without storing credentials in Kubernetes.

**Recommended for:** GKE deployments

---

## Overview

Workload Identity allows Kubernetes service accounts to act as Google Cloud service accounts, eliminating the need to store JSON keys in secrets.

**Benefits:**
- No credentials stored in Kubernetes
- Automatic credential rotation
- Fine-grained IAM permissions
- Better security posture

---

## Prerequisites

- GKE cluster with Workload Identity enabled
- GCS bucket created
- `gcloud` CLI configured

---

## Setup Steps

### Step 1: Enable Workload Identity on GKE Cluster

```bash
# For existing cluster
gcloud container clusters update CLUSTER_NAME \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --region=REGION

# For new cluster (already enabled by default in recent GKE versions)
gcloud container clusters create CLUSTER_NAME \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --region=REGION
```

### Step 2: Create Google Cloud Service Account

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export GSA_NAME=redis-backup-sa
export BUCKET_NAME=redis-backups

# Create service account
gcloud iam service-accounts create ${GSA_NAME} \
  --display-name="Redis Enterprise Backup Service Account"

# Grant Storage Object Admin role on specific bucket
gcloud storage buckets add-iam-policy-binding gs://${BUCKET_NAME} \
  --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

### Step 3: Create Kubernetes Service Account

```bash
# Create service account in redis-enterprise namespace
kubectl create serviceaccount redis-backup-ksa \
  --namespace redis-enterprise
```

### Step 4: Bind Kubernetes SA to Google Cloud SA

```bash
# Allow Kubernetes SA to impersonate Google Cloud SA
gcloud iam service-accounts add-iam-policy-binding \
  ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[redis-enterprise/redis-backup-ksa]"

# Annotate Kubernetes SA
kubectl annotate serviceaccount redis-backup-ksa \
  --namespace redis-enterprise \
  iam.gke.io/gcp-service-account=${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
```

### Step 5: Configure Redis Enterprise Operator

Update operator deployment to use the service account:

```bash
kubectl patch deployment redis-enterprise-operator \
  --namespace redis-enterprise \
  --type merge \
  --patch '{"spec":{"template":{"spec":{"serviceAccountName":"redis-backup-ksa"}}}}'
```

### Step 6: Deploy Database with GCS Backup

**Important:** Remove `gcsSecretName` from backup configuration when using Workload Identity.

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
  tlsMode: enabled
  replication: true
  persistence: aofEverySecond
  
  backup:
    interval: 24
    gcs:
      # NO gcsSecretName - Workload Identity provides credentials
      bucketName: redis-backups
      subdir: production/test-db
```

---

## Verification

### Test Workload Identity

```bash
# Create test pod with service account
kubectl run gcloud-test \
  --image=google/cloud-sdk:slim \
  --serviceaccount=redis-backup-ksa \
  --namespace=redis-enterprise \
  -it --rm -- bash

# Inside pod, test GCS access
gcloud storage ls gs://redis-backups/
```

### Check Service Account Annotation

```bash
kubectl get serviceaccount redis-backup-ksa \
  --namespace redis-enterprise \
  -o yaml | grep iam.gke.io
```

Expected output:
```yaml
annotations:
  iam.gke.io/gcp-service-account: redis-backup-sa@PROJECT_ID.iam.gserviceaccount.com
```

---

## Troubleshooting

### "Permission Denied" Errors

**Check IAM binding:**
```bash
gcloud iam service-accounts get-iam-policy \
  ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
```

Should show `roles/iam.workloadIdentityUser` for the Kubernetes SA.

### Operator Not Using Service Account

**Verify operator pod:**
```bash
kubectl get pod -n redis-enterprise -l name=redis-enterprise-operator \
  -o jsonpath='{.items[0].spec.serviceAccountName}'
```

Should output: `redis-backup-ksa`

---

## Best Practices

1. **Use separate service accounts** for different environments
2. **Grant minimal permissions** (only required buckets)
3. **Monitor IAM policy changes** with Cloud Audit Logs
4. **Document service account mappings** in runbooks

---

## Additional Resources

- [GKE Workload Identity Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [IAM Best Practices](https://cloud.google.com/iam/docs/best-practices)

