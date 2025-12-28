# GCP Secret Manager Integration

Integrate Redis Enterprise with GCP Secret Manager using External Secrets Operator.

## 📋 Overview

GCP Secret Manager provides centralized secret management with automatic rotation, audit logging, and fine-grained access control.

**Benefits:**
- ✅ Automatic secret rotation
- ✅ Cloud Audit Logs
- ✅ IAM-based access control
- ✅ Encryption at rest
- ✅ No secrets in Git

## ✅ Prerequisites

1. **GKE Cluster** with Workload Identity enabled
2. **External Secrets Operator** installed
3. **gcloud CLI** configured
4. **kubectl** access to cluster

## 🔧 Setup

### Step 1: Enable Secret Manager API

```bash
# Variables
PROJECT_ID="your-gcp-project"
REGION="us-central1"

# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
```

### Step 2: Create Secrets in GCP Secret Manager

```bash
# Create admin password secret
echo -n "RedisAdmin123!" | gcloud secrets create redis-admin-password \
  --data-file=- \
  --project=$PROJECT_ID

# Create database password secret
echo -n "RedisDB123!" | gcloud secrets create redis-database-password \
  --data-file=- \
  --project=$PROJECT_ID

# List secrets
gcloud secrets list --project=$PROJECT_ID
```

### Step 3: Enable Workload Identity on GKE

```bash
# Get cluster name
CLUSTER_NAME="your-gke-cluster"

# Enable Workload Identity (if not already enabled)
gcloud container clusters update $CLUSTER_NAME \
  --workload-pool=$PROJECT_ID.svc.id.goog \
  --region=$REGION
```

### Step 4: Create GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create redis-enterprise-secrets \
  --display-name="Redis Enterprise External Secrets" \
  --project=$PROJECT_ID

# Grant Secret Manager access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:redis-enterprise-secrets@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Step 5: Bind Kubernetes Service Account to GCP Service Account

```bash
# Bind Kubernetes SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  redis-enterprise-secrets@$PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[external-secrets-system/external-secrets]"

# Annotate Kubernetes service account
kubectl annotate serviceaccount external-secrets \
  -n external-secrets-system \
  iam.gke.io/gcp-service-account=redis-enterprise-secrets@$PROJECT_ID.iam.gserviceaccount.com
```

### Step 6: Create SecretStore

See: [01-secret-store.yaml](01-secret-store.yaml)

```bash
# Update YAML with your GCP project ID
# Then apply:
kubectl apply -f 01-secret-store.yaml

# Verify
kubectl get secretstore -n redis-enterprise
```

### Step 7: Create ExternalSecrets

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
# Add new secret version
echo -n "NewRedisAdmin456!" | gcloud secrets versions add redis-admin-password \
  --data-file=- \
  --project=$PROJECT_ID

# ESO will automatically sync within refreshInterval
```

## 🔍 Troubleshooting

### Common Issues

1. **Access denied errors**
   - Verify Workload Identity is enabled
   - Check GCP SA has secretAccessor role
   - Verify Kubernetes SA annotation

2. **Secret not found**
   - Verify secret exists in Secret Manager
   - Check project ID in SecretStore

## 📚 References

- GCP Secret Manager: https://cloud.google.com/secret-manager
- Workload Identity: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
- External Secrets GCP Provider: https://external-secrets.io/latest/provider/google-secrets-manager/

