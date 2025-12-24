# Secret Management Guide

This guide explains how to generate and manage base64-encoded secrets for Redis Enterprise deployments.

## 📋 Default Credentials

**⚠️ WARNING: Change these credentials before production deployment!**

The default credentials used in this template are:
- **Username**: `admin@redis.com`
- **Password**: `RedisAdmin123!`

Base64 encoded:
- **Username**: `YWRtaW5AcmVkaXMuY29t`
- **Password**: `UmVkaXNBZG1pbjEyMyE=`

## 🔐 Generating Custom Secrets

### Encode Credentials to Base64

```bash
# Encode username
echo -n 'your-username@example.com' | base64

# Encode password
echo -n 'YourSecurePassword123!' | base64
```

**Important:** Use `-n` flag to avoid encoding the newline character.

### Decode Base64 Credentials

```bash
# Decode username
echo -n 'YWRtaW5AcmVkaXMuY29t' | base64 -d

# Decode password
echo -n 'UmVkaXNBZG1pbjEyMyE=' | base64 -d
```

## 📝 Updating Secrets in YAML Files

### Single-Region Deployment

**Update `single-region/00-rec-admin-secret.yaml`:**
```yaml
data:
  password: <your-base64-encoded-password>
  username: <your-base64-encoded-username>
```

**Update `single-region/02-redb-secret.yaml`:**
```yaml
data:
  password: <your-base64-encoded-password>
```

### Active-Active Deployment

**Update both cluster secrets:**
- `active-active/clusterA/00-rec-admin-secret.yaml`
- `active-active/clusterB/00-rec-admin-secret.yaml`

**Update remote cluster secrets:**
- `active-active/clusterA/01-rerc-secrets.yaml`
- `active-active/clusterB/01-rerc-secrets.yaml`

**Update database secrets:**
- `active-active/clusterA/02-reaadb-secret.yaml`
- `active-active/clusterB/02-reaadb-secret.yaml`

## 🔄 Rotating Secrets

### After Initial Deployment

If you need to change credentials after deployment:

```bash
# 1. Update the secret
oc create secret generic rec-a \
  --from-literal=username=new-admin@example.com \
  --from-literal=password=NewSecurePassword123! \
  --dry-run=client -o yaml | oc apply -f -

# 2. Restart Redis Enterprise pods (if needed)
oc rollout restart statefulset/rec-a -n redis-ns-a
```

## 🛡️ Security Best Practices

1. **Never commit secrets to version control**
   - Use `.gitignore` for files containing actual credentials
   - Keep this template with placeholder values only

2. **Use strong passwords**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, and special characters
   - Avoid common words or patterns

3. **Different credentials per environment**
   - Development, staging, and production should have different credentials
   - Never reuse production credentials in other environments

4. **Consider using external secret management**
   - OpenShift Sealed Secrets
   - HashiCorp Vault
   - AWS Secrets Manager / Azure Key Vault / GCP Secret Manager

5. **Regular rotation**
   - Rotate credentials periodically (e.g., every 90 days)
   - Rotate immediately if credentials are compromised

## 📚 Additional Resources

- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [OpenShift Secrets Management](https://docs.openshift.com/container-platform/latest/nodes/pods/nodes-pods-secrets.html)
- [Redis Enterprise Security Best Practices](https://redis.io/docs/latest/operate/rs/security/)

