# Custom CA Certificates for Redis Enterprise

Use your own Certificate Authority (CA) or generate self-signed certificates for Redis Enterprise.

## 📋 Table of Contents

- [Overview](#overview)
- [When to Use Custom CA](#when-to-use-custom-ca)
- [Quick Start Guide](#quick-start-guide)
- [Certificate Generation](#certificate-generation)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This guide shows how to use custom CA certificates with Redis Enterprise instead of cert-manager.

**Use Cases:**
- ✅ You have an existing Certificate Authority
- ✅ You want to learn certificate generation manually
- ✅ You need specific certificate attributes
- ✅ You don't want to install cert-manager

**Comparison with cert-manager:**

| Feature | Custom CA | cert-manager |
|---------|-----------|--------------|
| **Setup Complexity** | Low | Medium |
| **Certificate Generation** | Manual | Automatic |
| **Renewal** | Manual | Automatic |
| **Best For** | Simple setups, learning | Production, automation |

---

## 🤔 When to Use Custom CA

### ✅ Use Custom CA If:

- You already have certificates from your company CA
- You want to learn how certificates work
- You're doing a quick test/demo
- You don't want to install cert-manager

### ❌ Don't Use Custom CA If:

- You want automatic certificate renewal
- You're setting up production (use cert-manager instead)
- You don't have certificates yet (use cert-manager instead)

**Recommendation:** For production, use [cert-manager](../cert-manager/README.md) for automatic renewal.

---

## 📦 Quick Start Guide

### Prerequisites

```bash
# Verify you have a Kubernetes cluster
kubectl cluster-info

# Verify Redis Enterprise Operator is installed
kubectl get deployment redis-enterprise-operator -n redis-enterprise

# Verify you have openssl installed
openssl version
```

---

### Step 1: Generate Certificates (10 minutes)

**Option A: Generate Self-Signed Certificates (for lab/testing)**

```bash
# Create a directory for certificates
mkdir -p /tmp/redis-certs
cd /tmp/redis-certs

# 1. Generate CA (Certificate Authority)
openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
  -subj "/C=US/ST=California/L=SanFrancisco/O=RedisLab/CN=Redis-CA"

# 2. Generate API certificate
openssl genrsa -out api.key 4096

openssl req -new -key api.key -out api.csr \
  -subj "/C=US/ST=California/L=SanFrancisco/O=RedisLab/CN=rec-api.redis-enterprise.svc.cluster.local"

# Create SAN config for API certificate
cat > api-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = rec-api.redis-enterprise.svc.cluster.local
DNS.2 = rec-ui.redis-enterprise.svc.cluster.local
DNS.3 = rec.redis-enterprise.svc.cluster.local
DNS.4 = *.rec.redis-enterprise.svc.cluster.local
EOF

openssl x509 -req -in api.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out api.crt -days 365 -sha256 \
  -extfile api-san.cnf -extensions v3_req

# 3. Generate Cluster Manager (CM) certificate
openssl genrsa -out cm.key 4096

openssl req -new -key cm.key -out cm.csr \
  -subj "/C=US/ST=California/L=SanFrancisco/O=RedisLab/CN=rec-cm.redis-enterprise.svc.cluster.local"

cat > cm-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = rec-cm.redis-enterprise.svc.cluster.local
DNS.2 = *.rec.redis-enterprise.svc.cluster.local
EOF

openssl x509 -req -in cm.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out cm.crt -days 365 -sha256 \
  -extfile cm-san.cnf -extensions v3_req

# 4. Generate Proxy certificate (for database TLS)
openssl genrsa -out proxy.key 4096

openssl req -new -key proxy.key -out proxy.csr \
  -subj "/C=US/ST=California/L=SanFrancisco/O=RedisLab/CN=rec-proxy.redis-enterprise.svc.cluster.local"

cat > proxy-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = rec-proxy.redis-enterprise.svc.cluster.local
DNS.2 = *.rec.redis-enterprise.svc.cluster.local
EOF

openssl x509 -req -in proxy.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out proxy.crt -days 365 -sha256 \
  -extfile proxy-san.cnf -extensions v3_req

# Verify certificates
echo "=== Verifying Certificates ==="
openssl x509 -in api.crt -noout -text | grep -A1 "Subject:"
openssl x509 -in api.crt -noout -text | grep -A3 "Subject Alternative Name"
openssl x509 -in cm.crt -noout -text | grep -A1 "Subject:"
openssl x509 -in proxy.crt -noout -text | grep -A1 "Subject:"

echo "✅ Certificates generated successfully!"
ls -lh /tmp/redis-certs/
```

**Option B: Use Existing Certificates from Your Company CA**

If you already have certificates from your company CA:

```bash
# Copy your certificates to /tmp/redis-certs/
cp /path/to/your/ca.crt /tmp/redis-certs/
cp /path/to/your/api.crt /tmp/redis-certs/
cp /path/to/your/api.key /tmp/redis-certs/
cp /path/to/your/cm.crt /tmp/redis-certs/
cp /path/to/your/cm.key /tmp/redis-certs/
cp /path/to/your/proxy.crt /tmp/redis-certs/
cp /path/to/your/proxy.key /tmp/redis-certs/
```

---

### Step 2: Create Kubernetes Secrets (5 minutes)

```bash
# Create namespace if it doesn't exist
kubectl create namespace redis-enterprise --dry-run=client -o yaml | kubectl apply -f -

# Create secret for API certificate
kubectl create secret generic rec-api-tls \
  --from-file=ca.crt=/tmp/redis-certs/ca.crt \
  --from-file=tls.crt=/tmp/redis-certs/api.crt \
  --from-file=tls.key=/tmp/redis-certs/api.key \
  -n redis-enterprise

# Create secret for Cluster Manager certificate
kubectl create secret generic rec-cm-tls \
  --from-file=ca.crt=/tmp/redis-certs/ca.crt \
  --from-file=tls.crt=/tmp/redis-certs/cm.crt \
  --from-file=tls.key=/tmp/redis-certs/cm.key \
  -n redis-enterprise

# Create secret for Proxy certificate (for database TLS)
kubectl create secret generic rec-proxy-tls \
  --from-file=ca.crt=/tmp/redis-certs/ca.crt \
  --from-file=tls.crt=/tmp/redis-certs/proxy.crt \
  --from-file=tls.key=/tmp/redis-certs/proxy.key \
  -n redis-enterprise

# Verify secrets were created
kubectl get secret -n redis-enterprise | grep tls

# Expected output:
# rec-api-tls      Opaque   3      10s
# rec-cm-tls       Opaque   3      10s
# rec-proxy-tls    Opaque   3      10s
```

---

### Step 3: Deploy REC with Custom CA (5 minutes)

**Option A: New REC (recommended for testing)**

```bash
# Deploy REC with custom CA certificates
kubectl apply -f 02-rec-custom-ca.yaml

# Wait for REC to be ready (5-10 minutes)
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# Verify REC is using custom certificates
kubectl get rec rec -n redis-enterprise -o yaml | grep -A10 certificates
```

**Option B: Existing REC**

```bash
# Edit your existing REC
kubectl edit rec <your-rec-name> -n redis-enterprise

# Add this section under spec:
#   certificates:
#     apiCertificateSecretName: rec-api-tls
#     cmCertificateSecretName: rec-cm-tls

# Save and exit. REC will reload with new certificates.
```

---

### Step 4: Verify TLS is Working (5 minutes)

```bash
# 1. Check REC status
kubectl get rec -n redis-enterprise

# 2. Get REC UI service
kubectl get svc -n redis-enterprise | grep ui

# 3. Port-forward to REC UI (HTTPS)
kubectl port-forward svc/rec-ui -n redis-enterprise 8443:8443

# 4. Open browser to https://localhost:8443
# You'll see a certificate warning (expected for self-signed)
# Click "Advanced" → "Proceed" to access the UI

# 5. Check certificate in browser
# - Click the lock icon in address bar
# - View certificate details
# - Should show your custom CA as issuer
```

---

### Step 5: Create Database with TLS (10 minutes)

```bash
# Create password secret
kubectl create secret generic redis-db-tls-password \
  --from-literal=password=MySecurePassword123! \
  -n redis-enterprise

# Create database with TLS enabled
kubectl apply -f 03-redb-tls.yaml

# Wait for database to be ready
kubectl wait --for=condition=Ready redb/redis-db-tls -n redis-enterprise --timeout=300s

# Get database connection info
kubectl get redb redis-db-tls -n redis-enterprise
```

---

### Step 6: Test TLS Connection (5 minutes)

```bash
# Get database service and port
DB_SERVICE=$(kubectl get redb redis-db-tls -n redis-enterprise -o jsonpath='{.status.databaseURL}' | cut -d: -f1)
DB_PORT=$(kubectl get redb redis-db-tls -n redis-enterprise -o jsonpath='{.status.databaseURL}' | cut -d: -f2)

# Port-forward to database
kubectl port-forward svc/$DB_SERVICE -n redis-enterprise $DB_PORT:$DB_PORT &

# Test connection with TLS (requires redis-cli with TLS support)
redis-cli -h localhost -p $DB_PORT --tls --insecure -a MySecurePassword123! PING

# Expected output: PONG

# Test without TLS (should fail)
redis-cli -h localhost -p $DB_PORT -a MySecurePassword123! PING

# Expected output: Error (connection refused or protocol error)

# Stop port-forward
kill %1
```

---

## ✅ Success Criteria

After completing the quick start, you should have:

- ✅ Certificates generated (CA, API, CM, Proxy)
- ✅ Kubernetes secrets created with certificates
- ✅ REC configured with custom CA
- ✅ REC UI accessible via HTTPS
- ✅ Database created with TLS enabled
- ✅ Verified TLS connection to database

**Total Time: ~40 minutes**

---

## 📜 Certificate Generation Details

### Certificate Types Needed

Redis Enterprise requires different certificates for different components:

| Certificate | Purpose | Secret Name | Required |
|-------------|---------|-------------|----------|
| **API** | Cluster Manager UI/API | `rec-api-tls` | Yes |
| **CM** | Cluster Manager internal | `rec-cm-tls` | Yes |
| **Proxy** | Database client connections | `rec-proxy-tls` | Optional |

### Certificate Requirements

Each certificate must include:

1. **Subject Alternative Names (SANs)** - DNS names for the service
2. **Valid for 365+ days** - To avoid frequent renewal
3. **Signed by the same CA** - All certificates must trust each other
4. **RSA 2048+ or 4096 bits** - For security

### Example Certificate Details

**API Certificate:**
- CN: `rec-api.redis-enterprise.svc.cluster.local`
- SANs:
  - `rec-api.redis-enterprise.svc.cluster.local`
  - `rec-ui.redis-enterprise.svc.cluster.local`
  - `rec.redis-enterprise.svc.cluster.local`
  - `*.rec.redis-enterprise.svc.cluster.local`

**CM Certificate:**
- CN: `rec-cm.redis-enterprise.svc.cluster.local`
- SANs:
  - `rec-cm.redis-enterprise.svc.cluster.local`
  - `*.rec.redis-enterprise.svc.cluster.local`

**Proxy Certificate:**
- CN: `rec-proxy.redis-enterprise.svc.cluster.local`
- SANs:
  - `rec-proxy.redis-enterprise.svc.cluster.local`
  - `*.rec.redis-enterprise.svc.cluster.local`

---

## 🔍 Troubleshooting

### Certificate Not Loaded

```bash
# Check if secret exists
kubectl get secret rec-api-tls -n redis-enterprise

# Check secret contents
kubectl get secret rec-api-tls -n redis-enterprise -o yaml

# Verify certificate is valid
kubectl get secret rec-api-tls -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### Certificate Expired

```bash
# Check certificate expiry
kubectl get secret rec-api-tls -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# If expired, regenerate and update secret
# Follow Step 1 and Step 2 again
```

### Wrong Certificate Loaded

```bash
# Check which certificate REC is using
kubectl get rec rec -n redis-enterprise -o yaml | grep -A10 certificates

# Verify secret name matches
kubectl describe rec rec -n redis-enterprise | grep -i certificate
```

### TLS Connection Fails

```bash
# Check if database has TLS enabled
kubectl get redb redis-db-tls -n redis-enterprise -o yaml | grep -A5 tlsMode

# Check proxy certificate is configured
kubectl get rec rec -n redis-enterprise -o yaml | grep proxyCertificateSecretName

# Test with verbose output
redis-cli -h localhost -p $DB_PORT --tls --insecure -a MySecurePassword123! --verbose PING
```

---

## 🔄 Certificate Renewal

**⚠️ Important:** Custom CA certificates do NOT auto-renew. You must manually renew before expiry.

### Check Certificate Expiry

```bash
# Check all certificates
for cert in rec-api-tls rec-cm-tls rec-proxy-tls; do
  echo "=== $cert ==="
  kubectl get secret $cert -n redis-enterprise \
    -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
done
```

### Renew Certificates

```bash
# 1. Generate new certificates (follow Step 1)
# 2. Update secrets
kubectl create secret generic rec-api-tls \
  --from-file=ca.crt=/tmp/redis-certs/ca.crt \
  --from-file=tls.crt=/tmp/redis-certs/api.crt \
  --from-file=tls.key=/tmp/redis-certs/api.key \
  -n redis-enterprise \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart REC pods to load new certificates
kubectl rollout restart statefulset rec -n redis-enterprise
```

**Recommendation:** Use [cert-manager](../cert-manager/README.md) for automatic renewal in production.

---

## 📚 References

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Redis Enterprise TLS Configuration](https://redis.io/docs/latest/operate/kubernetes/security/tls/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)


