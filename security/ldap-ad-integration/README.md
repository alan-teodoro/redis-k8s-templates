# LDAP/Active Directory Integration for Redis Enterprise

Complete guide for integrating Redis Enterprise with LDAP and Active Directory for centralized authentication.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [LDAP Configuration](#ldap-configuration)
- [Active Directory Configuration](#active-directory-configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Benefits:**
- ✅ Centralized user management
- ✅ Single sign-on (SSO)
- ✅ Role-based access control (RBAC)
- ✅ Compliance with corporate policies
- ✅ Audit trail

**Supported:**
- LDAP (OpenLDAP, etc.)
- Active Directory (Microsoft AD)
- LDAPS (LDAP over SSL/TLS)

---

## 📋 Prerequisites

1. **LDAP/AD Server:**
   - LDAP server accessible from Kubernetes cluster
   - LDAP bind credentials
   - LDAP schema knowledge

2. **Redis Enterprise:**
   - Redis Enterprise Cluster deployed
   - Admin access to cluster

3. **Network:**
   - Network connectivity to LDAP server (port 389 or 636)
   - DNS resolution for LDAP server

---

## 🔧 LDAP Configuration

### 1. Create LDAP Configuration Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ldap-config
  namespace: redis-enterprise
type: Opaque
stringData:
  ldap-config.json: |
    {
      "name": "ldap-integration",
      "protocol": "ldap",
      "server": "ldap.example.com:389",
      "bind_dn": "cn=admin,dc=example,dc=com",
      "bind_pass": "admin-password",
      "search_base": "ou=users,dc=example,dc=com",
      "search_filter": "(uid=%u)",
      "user_dn_template": "uid=%u,ou=users,dc=example,dc=com"
    }
```

```bash
kubectl apply -f ldap-config-secret.yaml
```

### 2. Configure Redis Enterprise Cluster

```bash
# Copy LDAP config to cluster
kubectl cp ldap-config.json redis-enterprise/rec-0:/tmp/

# Configure LDAP
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config saslauthd_ldap_conf /tmp/ldap-config.json

# Enable SASLAUTHD
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config saslauthd enabled
```

### 3. Create Database with LDAP Authentication

```yaml
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: redis-db-ldap
  namespace: redis-enterprise
spec:
  memorySize: 2GB
  
  # Enable LDAP authentication
  authentication:
    saslauthd: true
  
  # Optional: ACL for LDAP users
  aclRules:
    - user: "ldap-user-1"
      acl: "allkeys +@all"
    - user: "ldap-user-2"
      acl: "~app:* +@read"
```

---

## 🏢 Active Directory Configuration

### 1. Create AD Configuration Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ad-config
  namespace: redis-enterprise
type: Opaque
stringData:
  ad-config.json: |
    {
      "name": "active-directory",
      "protocol": "ldaps",
      "server": "ad.corp.example.com:636",
      "bind_dn": "CN=Redis Service,OU=Service Accounts,DC=corp,DC=example,DC=com",
      "bind_pass": "service-account-password",
      "search_base": "OU=Users,DC=corp,DC=example,DC=com",
      "search_filter": "(&(objectClass=user)(sAMAccountName=%u))",
      "user_dn_template": "CN=%u,OU=Users,DC=corp,DC=example,DC=com",
      "tls_cacert_file": "/etc/ssl/certs/ca-bundle.crt"
    }
```

### 2. Configure TLS Certificate (for LDAPS)

```bash
# Create CA certificate secret
kubectl create secret generic ad-ca-cert \
  --from-file=ca.crt=ad-ca-cert.pem \
  -n redis-enterprise

# Mount certificate in REC
kubectl patch rec rec -n redis-enterprise --type='json' \
  -p='[{
    "op": "add",
    "path": "/spec/volumes",
    "value": [{
      "name": "ad-ca-cert",
      "secret": {"secretName": "ad-ca-cert"}
    }]
  }]'
```

### 3. Configure Active Directory

```bash
# Copy AD config to cluster
kubectl cp ad-config.json redis-enterprise/rec-0:/tmp/

# Configure AD
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config saslauthd_ldap_conf /tmp/ad-config.json

# Enable SASLAUTHD
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config saslauthd enabled
```

---

## 🧪 Testing

### Test LDAP Authentication

```bash
# Test with redis-cli
redis-cli -h redis-db-ldap.redis-enterprise.svc.cluster.local -p 12000 \
  --user ldap-user-1 \
  --pass ldap-password \
  PING

# Expected output: PONG
```

### Test from Application

```python
import redis

# Connect with LDAP credentials
r = redis.Redis(
    host='redis-db-ldap.redis-enterprise.svc.cluster.local',
    port=12000,
    username='ldap-user-1',
    password='ldap-password',
    decode_responses=True
)

# Test connection
print(r.ping())  # Should print: True
```

### Verify LDAP Configuration

```bash
# Check SASLAUTHD status
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config | grep saslauthd

# Test LDAP bind
kubectl exec -it rec-0 -n redis-enterprise -- \
  testsaslauthd -u ldap-user-1 -p ldap-password
```

---

## 🔍 Troubleshooting

### Issue: Authentication Failed

```bash
# Check SASLAUTHD logs
kubectl exec -it rec-0 -n redis-enterprise -- \
  tail -f /var/opt/redislabs/log/saslauthd.log

# Common issues:
# 1. Incorrect bind DN or password
# 2. Wrong search base
# 3. Network connectivity to LDAP server
# 4. TLS certificate issues (for LDAPS)
```

### Issue: Cannot Connect to LDAP Server

```bash
# Test network connectivity
kubectl exec -it rec-0 -n redis-enterprise -- \
  nc -zv ldap.example.com 389

# Test DNS resolution
kubectl exec -it rec-0 -n redis-enterprise -- \
  nslookup ldap.example.com

# Test LDAP query
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://ldap.example.com:389 \
  -D "cn=admin,dc=example,dc=com" \
  -w admin-password \
  -b "ou=users,dc=example,dc=com" \
  "(uid=test-user)"
```

### Issue: TLS Certificate Errors

```bash
# Verify certificate
kubectl exec -it rec-0 -n redis-enterprise -- \
  openssl s_client -connect ad.corp.example.com:636 -showcerts

# Check certificate expiry
kubectl exec -it rec-0 -n redis-enterprise -- \
  openssl x509 -in /etc/ssl/certs/ca-bundle.crt -noout -dates
```

---

## 📚 Related Documentation

- [RBAC](../rbac/README.md)
- [TLS Certificates](../tls-certificates/README.md)
- [Security Overview](../README.md)

---

## 🔗 References

- Redis Enterprise LDAP: https://redis.io/docs/latest/operate/rs/security/access-control/ldap/
- SASLAUTHD: https://www.cyrusimap.org/sasl/sasl/auxprop.html
- Active Directory: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/

