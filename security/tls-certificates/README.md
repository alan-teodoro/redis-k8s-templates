# TLS/SSL Certificates for Redis Enterprise

Complete guide for configuring TLS/SSL certificates for Redis Enterprise on Kubernetes.

## 📋 Table of Contents

- [Overview](#overview)
- [TLS Architecture](#tls-architecture)
- [Certificate Types](#certificate-types)
- [Custom CA Certificates](#custom-ca-certificates)
- [cert-manager Integration](#cert-manager-integration)
- [Certificate Rotation](#certificate-rotation)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Redis Enterprise supports TLS/SSL encryption for:

1. **Client-to-Proxy** - Encrypt client connections to databases
2. **Proxy-to-Database** - Encrypt internal proxy-to-shard communication
3. **Internode** - Encrypt communication between cluster nodes
4. **Control Plane** - Encrypt API and UI access

---

## 🏗️ TLS Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Redis Enterprise Cluster                 │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   Node 1     │◄───────►│   Node 2     │  Internode TLS  │
│  │              │  TLS    │              │                  │
│  └──────┬───────┘         └──────┬───────┘                 │
│         │                        │                          │
│         │  Proxy-to-DB TLS       │                          │
│         ▼                        ▼                          │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  Database    │         │  Database    │                 │
│  │  Shard 1     │         │  Shard 2     │                 │
│  └──────────────┘         └──────────────┘                 │
│         ▲                        ▲                          │
│         │  Client-to-Proxy TLS   │                          │
└─────────┼────────────────────────┼──────────────────────────┘
          │                        │
    ┌─────┴────┐            ┌─────┴────┐
    │  Client  │            │  Client  │
    │   App    │            │   App    │
    └──────────┘            └──────────┘
```

---

## 📜 Certificate Types

Redis Enterprise requires different certificates for different components:

| Certificate | Purpose | Required | Auto-Generated |
|-------------|---------|----------|----------------|
| **API Certificate** | Cluster Manager UI/API access | Yes | Yes (self-signed) |
| **Proxy Certificate** | Client-to-database connections | Optional | No |
| **CM Certificate** | Cluster Manager internal communication | Yes | Yes (self-signed) |
| **Syncer Certificate** | Active-Active replication | Optional | No |
| **Metrics Exporter** | Prometheus metrics endpoint | Optional | No |
| **LDAP Certificate** | LDAP server CA | Optional | No |

---

## 🔧 Custom CA Certificates

Use your own Certificate Authority (CA) for Redis Enterprise.

### Prerequisites

- Custom CA certificate and key
- Certificates signed by your CA for each component
- Kubernetes cluster with Redis Enterprise Operator installed

### Step 1: Create CA Certificate Secret

```bash
# Create secret with CA certificate
kubectl create secret generic custom-ca-cert \
  --from-file=ca.crt=./ca.crt \
  --from-file=tls.crt=./server.crt \
  --from-file=tls.key=./server.key \
  -n redis-enterprise
```

### Step 2: Configure REC with Custom CA

See: [custom-ca/02-rec-custom-ca.yaml](custom-ca/02-rec-custom-ca.yaml)

```yaml
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec
spec:
  nodes: 3
  
  # Custom certificates
  certificates:
    apiCertificateSecretName: custom-ca-cert
    cmCertificateSecretName: custom-ca-cert
    proxyCertificateSecretName: custom-ca-cert
    syncerCertificateSecretName: custom-ca-cert
    metricsExporterCertificateSecretName: custom-ca-cert
```

### Step 3: Enable TLS on Database

See: [custom-ca/03-redb-tls.yaml](custom-ca/03-redb-tls.yaml)

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: redis-db
spec:
  memorySize: 1GB
  
  # Enable TLS for client connections
  tlsMode: enabled  # or 'required' to enforce TLS
  
  # Optional: Client authentication (mTLS)
  clientAuthenticationCertificates:
    - client-cert-secret
```

### Step 4: Verify TLS Configuration

```bash
# Check REC status
kubectl get rec -n redis-enterprise

# Check certificates
kubectl describe rec rec -n redis-enterprise | grep -A 10 "Certificates"

# Test TLS connection
openssl s_client -connect <database-endpoint>:443 \
  -servername <database-fqdn> \
  -CAfile ca.crt
```

---

## 🤖 cert-manager Integration

Automate certificate lifecycle management with cert-manager.

### Why cert-manager?

- ✅ **Automatic certificate renewal** - No manual intervention
- ✅ **Multiple issuers** - Let's Encrypt, Vault, self-signed, etc.
- ✅ **Certificate rotation** - Seamless rotation before expiry
- ✅ **Kubernetes-native** - CRDs for certificate management

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       cert-manager                           │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   Issuer     │────────►│ Certificate  │                 │
│  │ (Let's       │         │   Request    │                 │
│  │  Encrypt)    │         └──────┬───────┘                 │
│  └──────────────┘                │                          │
│                                   │                          │
│                                   ▼                          │
│                          ┌──────────────┐                   │
│                          │  Certificate │                   │
│                          │   (CRD)      │                   │
│                          └──────┬───────┘                   │
│                                 │                            │
│                                 ▼                            │
│                          ┌──────────────┐                   │
│                          │   Secret     │                   │
│                          │ (TLS cert)   │                   │
│                          └──────────────┘                   │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │ Redis Enterprise       │
                    │ Cluster (REC)          │
                    └────────────────────────┘
```

### Step 1: Install cert-manager

See: [cert-manager/01-install-cert-manager.yaml](cert-manager/01-install-cert-manager.yaml)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### Step 2: Create ClusterIssuer

See: [cert-manager/02-cluster-issuer.yaml](cert-manager/02-cluster-issuer.yaml)

**Options:**
- **Self-Signed** - For testing/development
- **Let's Encrypt** - For public-facing endpoints
- **Vault** - For enterprise PKI
- **CA** - For existing CA infrastructure

### Step 3: Create Certificates

See: [cert-manager/03-rec-certificates.yaml](cert-manager/03-rec-certificates.yaml)

cert-manager will automatically:
1. Request certificate from issuer
2. Create Kubernetes secret with certificate
3. Renew certificate before expiry

### Step 4: Configure REC with cert-manager

See: [cert-manager/04-rec-cert-manager.yaml](cert-manager/04-rec-cert-manager.yaml)

---

## 🔄 Certificate Rotation

### Automatic Rotation (cert-manager)

cert-manager automatically renews certificates when they are 2/3 through their lifetime.

**Example:** 90-day certificate → renewed at day 60

```bash
# Check certificate status
kubectl get certificate -n redis-enterprise

# Check certificate expiry
kubectl get secret rec-api-cert -n redis-enterprise -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -enddate
```

### Manual Rotation (Custom CA)

1. Generate new certificates
2. Update Kubernetes secrets
3. Restart Redis Enterprise pods (operator handles this)

```bash
# Update secret with new certificate
kubectl create secret generic custom-ca-cert \
  --from-file=ca.crt=./new-ca.crt \
  --from-file=tls.crt=./new-server.crt \
  --from-file=tls.key=./new-server.key \
  -n redis-enterprise \
  --dry-run=client -o yaml | kubectl apply -f -

# Operator will automatically detect and apply changes
```

---

## 🔍 Troubleshooting

### Issue: Certificate Verification Failed

**Symptoms:**
```
SSL certificate problem: unable to get local issuer certificate
```

**Solution:**
```bash
# Verify CA certificate is in the secret
kubectl get secret custom-ca-cert -n redis-enterprise -o jsonpath='{.data.ca\.crt}' | base64 -d

# Ensure CA certificate is trusted by clients
# Add CA certificate to client's trust store
```

### Issue: TLS Handshake Timeout

**Symptoms:**
```
TLS handshake timeout
```

**Solution:**
```bash
# Check if proxy certificate matches database FQDN
openssl s_client -connect <database-endpoint>:443 -servername <database-fqdn>

# Verify SNI (Server Name Indication) is correct
# Database FQDN must match certificate CN or SAN
```

### Issue: Certificate Expired

**Symptoms:**
```
certificate has expired or is not yet valid
```

**Solution:**
```bash
# Check certificate expiry
kubectl get secret rec-api-cert -n redis-enterprise -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -dates

# If using cert-manager, check certificate status
kubectl describe certificate rec-api-cert -n redis-enterprise

# Force renewal (cert-manager)
kubectl delete certificaterequest -n redis-enterprise --all
```

### Issue: Wrong Certificate Loaded

**Symptoms:**
```
certificate is valid for <wrong-domain>, not <expected-domain>
```

**Solution:**
```bash
# Check certificate subject and SANs
kubectl get secret rec-api-cert -n redis-enterprise -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -text | grep -A 5 "Subject Alternative Name"

# Ensure certificate includes all required FQDNs
# For databases: *.redis.example.com or specific database FQDNs
```

---

## ✅ Best Practices

### 1. **Use cert-manager for Production**
- ✅ Automatic certificate renewal
- ✅ Centralized certificate management
- ✅ Integration with enterprise PKI (Vault, Venafi)

### 2. **Enable TLS for All Components**
- ✅ Client-to-proxy (database TLS)
- ✅ Proxy-to-database (internal TLS)
- ✅ Internode communication
- ✅ Control plane (API/UI)

### 3. **Use Strong Cipher Suites**
```yaml
spec:
  tlsMode: enabled
  # Recommended cipher suites (TLS 1.2+)
  # Configured at REC level, not REDB
```

### 4. **Implement Certificate Monitoring**
```bash
# Monitor certificate expiry with Prometheus
# Alert 30 days before expiry
```

### 5. **Regular Certificate Rotation**
- ✅ Rotate certificates every 90 days (or less)
- ✅ Use short-lived certificates (Let's Encrypt: 90 days)
- ✅ Automate rotation with cert-manager

### 6. **Secure Private Keys**
- ✅ Store private keys in Kubernetes secrets
- ✅ Use External Secrets Operator for cloud KMS
- ✅ Never commit private keys to Git
- ✅ Restrict secret access with RBAC

### 7. **Test TLS Configuration**
```bash
# Test TLS connection
redis-cli -h <database-endpoint> -p 443 --tls \
  --cacert ca.crt \
  --sni <database-fqdn> \
  PING

# Test with openssl
openssl s_client -connect <database-endpoint>:443 \
  -servername <database-fqdn> \
  -CAfile ca.crt
```

### 8. **Document Certificate Requirements**
- ✅ Certificate validity period
- ✅ Required SANs (Subject Alternative Names)
- ✅ Key size (minimum 2048-bit RSA or 256-bit ECDSA)
- ✅ Signature algorithm (SHA-256 or better)

---

## 📚 Related Documentation

- [Custom CA Certificates](custom-ca/README.md) - Using your own CA
- [cert-manager Integration](cert-manager/README.md) - Automated certificate management
- [External Secrets](../external-secrets/README.md) - Secure secret management
- [Network Policies](../network-policies/README.md) - Network security

---

## 🔗 References

- Redis Enterprise TLS: https://redis.io/docs/latest/operate/rs/security/encryption/tls/
- cert-manager Documentation: https://cert-manager.io/docs/
- Kubernetes TLS Secrets: https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets

