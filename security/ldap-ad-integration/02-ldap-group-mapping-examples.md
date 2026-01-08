# LDAP Group Mapping Examples

This document provides examples of how to map LDAP groups to Redis Enterprise roles.

## 📋 Available Redis Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| **Cluster Admin** | Full cluster management | All cluster operations |
| **Cluster Member** | View cluster configuration | Read-only cluster access |
| **Cluster Viewer** | Read-only cluster access | View cluster status |
| **DB Admin** | Full database management | Create, edit, delete databases |
| **DB Member** | Read/write database access | Connect and use databases |
| **DB Viewer** | Read-only database access | View database configuration |
| **None** | No access | For testing/blocking access |

---

## 🎯 Samba AD Groups → Redis Roles Mapping

For our Samba AD setup (redis.training.local):

| LDAP Group | Distinguished Name | Redis Role | Use Case |
|------------|-------------------|------------|----------|
| **Redis-Admins** | CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local | DB Admin | Full database management |
| **Redis-Developers** | CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local | DB Member | Read/write database access |
| **Redis-Viewers** | CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local | DB Viewer | Read-only database access |

---

## 🖥️ Method 1: Using Cluster Manager UI

### **Step 1: Access Cluster Manager UI**

```bash
# Port-forward to UI
kubectl port-forward svc/rec-ui 8443:8443 -n redis-enterprise

# Open browser
open https://localhost:8443
```

### **Step 2: Login**

- **Username:** Get from secret
  ```bash
  kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d
  ```
- **Password:** Get from secret
  ```bash
  kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
  ```

### **Step 3: Create LDAP Mappings**

1. Navigate to: **Access Control → LDAP Mappings**
2. Click: **+ Create LDAP Mapping**
3. Fill in the form:

**Mapping 1: Redis-Admins**
- **Unique mapping name:** `redis-admins-mapping`
- **Distinguished Name:** `CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local`
- **Role:** `DB Admin`
- **Email:** (optional)
- Click: **Save**

**Mapping 2: Redis-Developers**
- **Unique mapping name:** `redis-developers-mapping`
- **Distinguished Name:** `CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local`
- **Role:** `DB Member`
- Click: **Save**

**Mapping 3: Redis-Viewers**
- **Unique mapping name:** `redis-viewers-mapping`
- **Distinguished Name:** `CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local`
- **Role:** `DB Viewer`
- Click: **Save**

---

## 🔧 Method 2: Using Redis Enterprise API

### **Step 1: Get API Credentials**

```bash
# Get API endpoint
API_URL="https://$(kubectl get svc rec -n redis-enterprise -o jsonpath='{.spec.clusterIP}'):9443"

# Get admin credentials
ADMIN_USER=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

echo "API URL: $API_URL"
echo "Admin User: $ADMIN_USER"
```

### **Step 2: Create LDAP Mappings**

**Mapping 1: Redis-Admins → DB Admin**

```bash
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-admins-mapping",
    "dn": "CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Admin"
  }'
```

**Mapping 2: Redis-Developers → DB Member**

```bash
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-developers-mapping",
    "dn": "CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Member"
  }'
```

**Mapping 3: Redis-Viewers → DB Viewer**

```bash
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-viewers-mapping",
    "dn": "CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Viewer"
  }'
```

### **Step 3: Verify Mappings**

```bash
# List all LDAP mappings
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X GET \
  "$API_URL/v1/ldap_mappings" | jq .
```

**Expected output:**
```json
[
  {
    "name": "redis-admins-mapping",
    "dn": "CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Admin"
  },
  {
    "name": "redis-developers-mapping",
    "dn": "CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Member"
  },
  {
    "name": "redis-viewers-mapping",
    "dn": "CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Viewer"
  }
]
```

---

## ✅ Verification

After creating the mappings, verify that users can authenticate:

```bash
# Test with redis-admin (should have DB Admin role)
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  PING

# Test with redis-dev1 (should have DB Member role)
redis-cli -h localhost -p 12000 \
  --user redis-dev1 \
  --pass RedisDev123! \
  PING

# Test with redis-viewer1 (should have DB Viewer role)
redis-cli -h localhost -p 12000 \
  --user redis-viewer1 \
  --pass RedisView123! \
  PING
```

All should return: `PONG`

---

## 🔗 References

- [Redis Enterprise LDAP Documentation](https://redis.io/docs/latest/operate/rs/security/access-control/ldap/)
- [Redis Enterprise API Reference](https://redis.io/docs/latest/operate/rs/references/rest-api/)

