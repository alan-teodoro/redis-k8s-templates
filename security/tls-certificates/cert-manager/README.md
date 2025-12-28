# cert-manager Integration for Redis Enterprise

Automate TLS certificate lifecycle management for Redis Enterprise using cert-manager.

## 📋 Table of Contents

- [Overview](#overview)
- [Why cert-manager?](#why-cert-manager)
- [Architecture](#architecture)
- [Installation](#installation)
- [Certificate Issuers](#certificate-issuers)
- [Certificate Management](#certificate-management)
- [Automatic Renewal](#automatic-renewal)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

cert-manager is a Kubernetes-native certificate management controller that automates the issuance and renewal of TLS certificates.

**Benefits:**
- ✅ Automatic certificate renewal
- ✅ Multiple certificate issuers (Let's Encrypt, Vault, self-signed, CA)
- ✅ Kubernetes-native (CRDs)
- ✅ Zero-downtime certificate rotation
- ✅ Integration with enterprise PKI

---

## 🤔 Why cert-manager?

### Without cert-manager (Manual)

```
┌─────────────────────────────────────────────────────────┐
│  Manual Certificate Management                          │
│                                                          │
│  1. Generate certificate manually                       │
│  2. Create Kubernetes secret                            │
│  3. Configure REC to use secret                         │
│  4. Monitor certificate expiry                          │
│  5. Manually renew before expiry                        │
│  6. Update secret with new certificate                  │
│  7. Restart pods to load new certificate                │
│                                                          │
│  ❌ Manual intervention required                        │
│  ❌ Risk of certificate expiry                          │
│  ❌ Downtime during renewal                             │
└─────────────────────────────────────────────────────────┘
```

### With cert-manager (Automated)

```
┌─────────────────────────────────────────────────────────┐
│  Automated Certificate Management                       │
│                                                          │
│  1. Define Certificate CRD                              │
│  2. cert-manager requests certificate from issuer       │
│  3. cert-manager creates Kubernetes secret              │
│  4. Configure REC to use secret                         │
│  5. cert-manager monitors expiry                        │
│  6. cert-manager auto-renews at 2/3 lifetime            │
│  7. cert-manager updates secret                         │
│  8. Operator detects change and reloads                 │
│                                                          │
│  ✅ Fully automated                                     │
│  ✅ No risk of expiry                                   │
│  ✅ Zero-downtime renewal                               │
└─────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      cert-manager                             │
│                                                               │
│  ┌────────────────┐         ┌────────────────┐              │
│  │  ClusterIssuer │────────►│  Certificate   │              │
│  │  (Let's        │         │     (CRD)      │              │
│  │   Encrypt)     │         └────────┬───────┘              │
│  └────────────────┘                  │                       │
│                                      │                       │
│                                      ▼                       │
│                          ┌────────────────────┐             │
│                          │ CertificateRequest │             │
│                          │      (CRD)         │             │
│                          └────────┬───────────┘             │
│                                   │                          │
│                                   ▼                          │
│                          ┌────────────────────┐             │
│                          │   Secret (TLS)     │             │
│                          │  (auto-created)    │             │
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

## 📦 Installation

### Step 1: Install cert-manager

See: [01-install-cert-manager.yaml](01-install-cert-manager.yaml)

```bash
# Install cert-manager CRDs and controller
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager

# Expected output:
# NAME                                       READY   STATUS    RESTARTS   AGE
# cert-manager-7d9f4d88d-xxxxx               1/1     Running   0          1m
# cert-manager-cainjector-7d9f4d88d-xxxxx    1/1     Running   0          1m
# cert-manager-webhook-7d9f4d88d-xxxxx       1/1     Running   0          1m
```

### Step 2: Verify Installation

```bash
# Check cert-manager CRDs
kubectl get crd | grep cert-manager

# Expected CRDs:
# certificaterequests.cert-manager.io
# certificates.cert-manager.io
# challenges.acme.cert-manager.io
# clusterissuers.cert-manager.io
# issuers.cert-manager.io
# orders.acme.cert-manager.io

# Check cert-manager version
kubectl get deployment -n cert-manager cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 🔑 Certificate Issuers

cert-manager supports multiple certificate issuers:

### 1. Self-Signed Issuer (Testing/Development)

See: [02-cluster-issuer.yaml](02-cluster-issuer.yaml) - SelfSigned section

**Use Case:** Testing, development, internal environments

**Pros:**
- ✅ No external dependencies
- ✅ Fast certificate issuance
- ✅ No cost

**Cons:**
- ❌ Not trusted by browsers/clients
- ❌ Manual trust configuration required
- ❌ Not suitable for production

### 2. Let's Encrypt (Public-Facing)

See: [02-cluster-issuer.yaml](02-cluster-issuer.yaml) - Let's Encrypt section

**Use Case:** Public-facing endpoints with valid domain names

**Pros:**
- ✅ Free certificates
- ✅ Trusted by all browsers/clients
- ✅ Automatic renewal

**Cons:**
- ❌ Requires public DNS
- ❌ Rate limits (50 certs/week per domain)
- ❌ Domain validation required

### 3. HashiCorp Vault (Enterprise PKI)

See: [02-cluster-issuer.yaml](02-cluster-issuer.yaml) - Vault section

**Use Case:** Enterprise environments with existing Vault infrastructure

**Pros:**
- ✅ Integration with enterprise PKI
- ✅ Centralized certificate management
- ✅ Audit logging
- ✅ Policy-based issuance

**Cons:**
- ❌ Requires Vault infrastructure
- ❌ More complex setup
- ❌ Additional cost

### 4. CA Issuer (Existing CA)

See: [02-cluster-issuer.yaml](02-cluster-issuer.yaml) - CA section

**Use Case:** Existing Certificate Authority infrastructure

**Pros:**
- ✅ Use existing CA
- ✅ Trusted within organization
- ✅ Full control over certificates

**Cons:**
- ❌ Manual CA management
- ❌ CA certificate must be in Kubernetes secret

---

## 📜 Certificate Management

### Create Certificates

See: [03-rec-certificates.yaml](03-rec-certificates.yaml)

cert-manager Certificate CRD defines:
- Certificate subject (CN, O, OU, etc.)
- Subject Alternative Names (SANs)
- Key size and algorithm
- Validity duration
- Issuer reference
- Secret name (where certificate will be stored)

**Example:**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: rec-api-cert
spec:
  secretName: rec-api-cert
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: rec.redis-enterprise.svc.cluster.local
  dnsNames:
    - rec.redis-enterprise.svc.cluster.local
    - rec-ui.redis-enterprise.svc.cluster.local
  duration: 2160h  # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
```

---

## 🔄 Automatic Renewal

cert-manager automatically renews certificates when they reach 2/3 of their lifetime.

**Example:** 90-day certificate → renewed at day 60

### Renewal Process

1. cert-manager monitors certificate expiry
2. At `renewBefore` threshold, creates new CertificateRequest
3. Issuer validates and signs new certificate
4. cert-manager updates Kubernetes secret
5. Redis Enterprise Operator detects secret change
6. Operator reloads certificate (zero-downtime)

### Monitor Renewal

```bash
# Check certificate status
kubectl get certificate -n redis-enterprise

# Check certificate expiry
kubectl describe certificate rec-api-cert -n redis-enterprise

# Check certificate in secret
kubectl get secret rec-api-cert -n redis-enterprise \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

---

## 🔍 Troubleshooting

See full troubleshooting guide in main [README.md](../README.md#troubleshooting)

### Common Issues

1. **Certificate not issued**
   - Check CertificateRequest: `kubectl get certificaterequest -n redis-enterprise`
   - Check issuer status: `kubectl describe clusterissuer <issuer-name>`

2. **Certificate expired**
   - Check renewBefore setting
   - Verify cert-manager is running
   - Check cert-manager logs

3. **Wrong certificate loaded**
   - Verify secretName in Certificate matches REC spec
   - Check certificate SANs include required FQDNs

---

## 📚 References

- cert-manager Documentation: https://cert-manager.io/docs/
- Let's Encrypt: https://letsencrypt.org/
- HashiCorp Vault: https://www.vaultproject.io/

