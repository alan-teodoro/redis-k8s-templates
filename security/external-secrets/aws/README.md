# AWS Secrets Manager Integration

Integrate Redis Enterprise with AWS Secrets Manager using External Secrets Operator.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Setup](#setup)
- [Usage](#usage)
- [Secret Rotation](#secret-rotation)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

AWS Secrets Manager provides centralized secret management with automatic rotation, audit logging, and fine-grained access control.

**Benefits:**
- ✅ Automatic secret rotation
- ✅ CloudTrail audit logging
- ✅ IAM-based access control
- ✅ Encryption at rest (KMS)
- ✅ No secrets in Git

---

## ✅ Prerequisites

1. **AWS EKS Cluster** with OIDC provider enabled
2. **External Secrets Operator** installed
3. **AWS CLI** configured
4. **kubectl** access to cluster

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AWS Secrets Manager                        │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Secret: redis-enterprise/admin-password               │  │
│  │  Value: RedisAdmin123!                                 │  │
│  │  KMS Encryption: Enabled                               │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬──────────────────────────────┘
                                │
                                │ IRSA (IAM Role)
                                │
                                ▼
┌──────────────────────────────────────────────────────────────┐
│              External Secrets Operator (ESO)                  │
│                                                               │
│  ┌────────────────┐         ┌────────────────┐              │
│  │ SecretStore    │────────►│ ExternalSecret │              │
│  │  (AWS)         │         │                │              │
│  └────────────────┘         └────────┬───────┘              │
│                                      │                       │
│                                      ▼                       │
│                          ┌────────────────────┐             │
│                          │   Secret (K8s)     │             │
│                          │  rec-admin-pass    │             │
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

## 🔧 Setup

### Step 1: Enable OIDC Provider (if not already enabled)

```bash
# Get cluster name
CLUSTER_NAME="your-eks-cluster"
AWS_REGION="us-east-1"

# Enable OIDC provider
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --approve
```

### Step 2: Create Secrets in AWS Secrets Manager

```bash
# Create admin password secret
aws secretsmanager create-secret \
  --name redis-enterprise/admin-password \
  --description "Redis Enterprise admin password" \
  --secret-string "RedisAdmin123!" \
  --region $AWS_REGION

# Create database password secret
aws secretsmanager create-secret \
  --name redis-enterprise/database-password \
  --description "Redis database password" \
  --secret-string "RedisDB123!" \
  --region $AWS_REGION

# Verify secrets
aws secretsmanager list-secrets --region $AWS_REGION
```

### Step 3: Create IAM Policy

See: [01-iam-policy.json](01-iam-policy.json)

```bash
# Create IAM policy
aws iam create-policy \
  --policy-name RedisEnterpriseSecretsManagerPolicy \
  --policy-document file://01-iam-policy.json

# Get policy ARN
POLICY_ARN=$(aws iam list-policies \
  --query 'Policies[?PolicyName==`RedisEnterpriseSecretsManagerPolicy`].Arn' \
  --output text)

echo "Policy ARN: $POLICY_ARN"
```

### Step 4: Create IAM Role for Service Account (IRSA)

```bash
# Get OIDC provider
OIDC_PROVIDER=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed -e "s/^https:\/\///")

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:external-secrets-system:external-secrets",
          "$OIDC_PROVIDER:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name RedisEnterpriseExternalSecretsRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name RedisEnterpriseExternalSecretsRole \
  --policy-arn $POLICY_ARN

# Get role ARN
ROLE_ARN=$(aws iam get-role \
  --role-name RedisEnterpriseExternalSecretsRole \
  --query 'Role.Arn' \
  --output text)

echo "Role ARN: $ROLE_ARN"
```

### Step 5: Annotate Service Account

```bash
# Annotate External Secrets service account with IAM role
kubectl annotate serviceaccount external-secrets \
  -n external-secrets-system \
  eks.amazonaws.com/role-arn=$ROLE_ARN
```

### Step 6: Create SecretStore

See: [02-secret-store.yaml](02-secret-store.yaml)

```bash
# Update YAML with your AWS region
# Then apply:
kubectl apply -f 02-secret-store.yaml

# Verify SecretStore
kubectl get secretstore -n redis-enterprise
kubectl describe secretstore aws-secrets-manager -n redis-enterprise
```

### Step 7: Create ExternalSecrets

See: [03-external-secret-admin.yaml](03-external-secret-admin.yaml)
See: [04-external-secret-database.yaml](04-external-secret-database.yaml)

```bash
# Create ExternalSecrets
kubectl apply -f 03-external-secret-admin.yaml
kubectl apply -f 04-external-secret-database.yaml

# Verify ExternalSecrets
kubectl get externalsecret -n redis-enterprise
kubectl describe externalsecret rec-admin-password -n redis-enterprise

# Verify Kubernetes secrets were created
kubectl get secret rec-admin-password -n redis-enterprise
kubectl get secret redis-db-password -n redis-enterprise
```

---

## 🚀 Usage

### Use Secrets in REC

See: [05-rec-external-secrets.yaml](05-rec-external-secrets.yaml)

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec
spec:
  # Use secret created by ExternalSecret
  credentialsSecret: rec-admin-password
```

### Use Secrets in REDB

See: [06-redb-external-secrets.yaml](06-redb-external-secrets.yaml)

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: redis-db
spec:
  # Use secret created by ExternalSecret
  databaseSecretName: redis-db-password
```

---

## 🔄 Secret Rotation

### Automatic Rotation

External Secrets Operator automatically syncs secrets from AWS Secrets Manager.

**Configuration:**
```yaml
spec:
  refreshInterval: 1h  # Sync every hour
```

### Manual Rotation

```bash
# Update secret in AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id redis-enterprise/admin-password \
  --secret-string "NewRedisAdmin456!" \
  --region $AWS_REGION

# ESO will automatically sync within refreshInterval
# Or force sync by deleting ExternalSecret:
kubectl delete externalsecret rec-admin-password -n redis-enterprise
kubectl apply -f 03-external-secret-admin.yaml
```

---

## 🔍 Troubleshooting

See full troubleshooting guide in [README.md](../README.md)

### Common Issues

1. **ExternalSecret not syncing**
   - Check SecretStore status
   - Verify IAM role permissions
   - Check ESO logs

2. **Access denied errors**
   - Verify IAM policy includes required permissions
   - Check IRSA annotation on service account
   - Verify trust policy

3. **Secret not found**
   - Verify secret exists in AWS Secrets Manager
   - Check secret name matches ExternalSecret spec
   - Verify AWS region

---

## 📚 References

- AWS Secrets Manager: https://aws.amazon.com/secrets-manager/
- IRSA Documentation: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- External Secrets AWS Provider: https://external-secrets.io/latest/provider/aws-secrets-manager/

