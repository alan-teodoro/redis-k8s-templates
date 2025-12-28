# Security for Redis Enterprise on Kubernetes

Complete security configurations and best practices for Redis Enterprise deployments on Kubernetes.

## 📁 Repository Structure

```
security/
├── README.md                           # This file - Security overview
├── tls-certificates/                   # TLS/SSL certificates
│   ├── README.md                       # Complete TLS guide
│   ├── custom-ca/                      # Custom CA certificates
│   │   ├── 01-ca-certificate-secret.yaml
│   │   ├── 02-rec-custom-ca.yaml
│   │   └── 03-redb-tls.yaml
│   └── cert-manager/                   # Automated cert management
│       ├── README.md
│       ├── 01-install-cert-manager.yaml
│       ├── 02-cluster-issuer.yaml
│       ├── 03-rec-certificates.yaml
│       └── 04-rec-cert-manager.yaml
├── external-secrets/                   # External Secrets Operator
│   ├── README.md                       # Complete ESO guide
│   ├── aws/                            # AWS Secrets Manager
│   │   ├── 01-install-eso.yaml
│   │   ├── 02-secret-store.yaml
│   │   └── 03-external-secret.yaml
│   ├── azure/                          # Azure Key Vault
│   │   ├── 01-install-eso.yaml
│   │   ├── 02-secret-store.yaml
│   │   └── 03-external-secret.yaml
│   └── gcp/                            # GCP Secret Manager
│       ├── 01-install-eso.yaml
│       ├── 02-secret-store.yaml
│       └── 03-external-secret.yaml
├── network-policies/                   # Network Policies
│   ├── README.md                       # Network security guide
│   ├── 01-deny-all.yaml
│   ├── 02-allow-redis-traffic.yaml
│   ├── 03-allow-monitoring.yaml
│   └── 04-allow-backup.yaml
├── pod-security/                       # Pod Security
│   ├── README.md                       # Pod security guide
│   ├── 01-pss-restricted.yaml          # Pod Security Standards
│   └── 02-security-context.yaml        # Security Context examples
├── ldap/                               # LDAP/AD Integration
│   ├── README.md                       # LDAP integration guide
│   ├── 01-ldap-config-secret.yaml
│   ├── 02-rec-ldap.yaml
│   └── active-directory.md             # Active Directory specific
└── rbac/                               # Kubernetes RBAC
    ├── README.md                       # RBAC guide
    ├── 01-service-account.yaml
    ├── 02-cluster-role.yaml
    └── 03-role-binding.yaml
```

---

## 🎯 Quick Start

### 1. TLS/SSL Certificates

Secure communication between Redis Enterprise components and clients.

**Choose your approach:**

| Approach | Use Case | Complexity | Automation |
|----------|----------|------------|------------|
| **Custom CA** | Existing PKI infrastructure | Low | Manual |
| **cert-manager** | Automated certificate lifecycle | Medium | Automatic |

📖 **See:** [tls-certificates/README.md](tls-certificates/README.md)

---

### 2. External Secrets Operator

Integrate with cloud-native secret management systems.

**Supported Providers:**

| Provider | Secret Store | Authentication |
|----------|--------------|----------------|
| **AWS** | Secrets Manager | IRSA (IAM Roles for Service Accounts) |
| **Azure** | Key Vault | Managed Identity |
| **GCP** | Secret Manager | Workload Identity |

📖 **See:** [external-secrets/README.md](external-secrets/README.md)

---

### 3. Network Policies

Control network traffic to/from Redis Enterprise pods.

**Default Policies:**
- ✅ Deny all ingress/egress by default
- ✅ Allow Redis client traffic (port 443, 10000-19999)
- ✅ Allow monitoring (Prometheus scraping)
- ✅ Allow backup traffic (S3/GCS/Azure)

📖 **See:** [network-policies/README.md](network-policies/README.md)

---

### 4. Pod Security Standards

Enforce security policies on Redis Enterprise pods.

**Security Levels:**
- **Privileged** - Unrestricted (not recommended)
- **Baseline** - Minimally restrictive
- **Restricted** - Heavily restricted (recommended)

📖 **See:** [pod-security/README.md](pod-security/README.md)

---

### 5. LDAP/Active Directory Integration

Centralized authentication for Redis Enterprise.

**Features:**
- ✅ LDAP/AD user authentication
- ✅ Group-based authorization
- ✅ TLS/SSL for LDAP connections
- ✅ Active Directory specific configurations

📖 **See:** [ldap/README.md](ldap/README.md)

---

### 6. Kubernetes RBAC

Control access to Redis Enterprise Kubernetes resources.

**Components:**
- Service Accounts for Redis Enterprise Operator
- Cluster Roles for operator permissions
- Role Bindings for namespace-scoped access

📖 **See:** [rbac/README.md](rbac/README.md)

---

## 🔐 Security Best Practices

### 1. **Enable TLS Everywhere**
- ✅ Client-to-proxy communication (TLS)
- ✅ Proxy-to-database communication (TLS)
- ✅ Internode communication (TLS)
- ✅ Control plane communication (TLS)

### 2. **Use Cloud-Native Secret Management**
- ✅ External Secrets Operator (AWS/Azure/GCP)
- ✅ HashiCorp Vault integration
- ✅ Avoid storing secrets in Git

### 3. **Implement Network Segmentation**
- ✅ Network Policies (deny-all by default)
- ✅ Separate namespaces for different environments
- ✅ Service Mesh (mTLS between services)

### 4. **Enforce Pod Security**
- ✅ Pod Security Standards (restricted)
- ✅ Security Context (non-root, read-only filesystem)
- ✅ Resource limits and quotas

### 5. **Centralized Authentication**
- ✅ LDAP/Active Directory integration
- ✅ SSO for Cluster Manager UI
- ✅ Role-based access control (RBAC)

### 6. **Regular Security Audits**
- ✅ Certificate rotation (automated with cert-manager)
- ✅ Secret rotation (automated with External Secrets)
- ✅ Security scanning (container images)
- ✅ Compliance checks (CIS benchmarks)

---

## 📚 Related Documentation

- [Backup & Restore](../backup-restore/README.md) - Secure backup configurations
- [Monitoring](../monitoring/README.md) - Security monitoring and alerting
- [Networking](../networking/README.md) - Secure ingress configurations
- [Integrations - Vault](../integrations/vault/README.md) - HashiCorp Vault integration

---

## 🆘 Support

For security-related questions or issues:
- Redis Enterprise Documentation: https://redis.io/docs/latest/operate/kubernetes/
- Redis Enterprise Security: https://redis.io/docs/latest/operate/rs/security/
- Kubernetes Security: https://kubernetes.io/docs/concepts/security/

