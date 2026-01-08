# LDAP/Active Directory Integration for Redis Enterprise

Complete guide for integrating Redis Enterprise with Samba Active Directory (redis.training.local).

## 📋 Table of Contents

- [Overview](#overview)
- [Samba AD Server Information](#samba-ad-server-information)
- [Step-by-Step Configuration](#step-by-step-configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Benefits:**
- ✅ Centralized user management
- ✅ Role-based access control (RBAC)
- ✅ Compliance with corporate policies
- ✅ Audit trail

**What you'll configure:**
- Samba Active Directory integration
- LDAP authentication for Redis databases
- ACL rules mapped to AD users
- Group-based access control

---

## 🌐 Samba AD Server Information

**Domain Configuration:**
- **Domain:** redis.training.local
- **Realm:** REDIS.TRAINING.LOCAL
- **NetBIOS Name:** REDISTRAINING
- **Base DN:** DC=redis,DC=training,DC=local

**LDAP Endpoints:**
- **LDAP URI:** ldap://3.83.144.166:389
- **LDAPS URI:** ldaps://3.83.144.166:636
- **Public IP:** 3.83.144.166

**Administrator Credentials:**
- **Username:** Administrator
- **Bind DN:** CN=Administrator,CN=Users,DC=redis,DC=training,DC=local

**Pre-configured Users:**

| Username | Password | Group | Access Level |
|----------|----------|-------|--------------|
| redis-admin | RedisAdmin123! | Redis-Admins | Full admin |
| redis-dev1 | RedisDev123! | Redis-Developers | Read/Write |
| redis-dev2 | RedisDev123! | Redis-Developers | Read/Write |
| redis-viewer1 | RedisView123! | Redis-Viewers | Read-only |
| redis-viewer2 | RedisView123! | Redis-Viewers | Read-only |
| redis-readonly | RedisRead123! | Redis-Viewers | Read-only |

**Security Groups:**

| Group Name | Description | Redis ACL |
|------------|-------------|-----------|
| Redis-Admins | Full administrative access | allkeys +@all |
| Redis-Developers | Read/Write access | allkeys +@all -@dangerous |
| Redis-Viewers | Read-only access | allkeys +@read |

---

## 🚀 Step-by-Step Configuration

### **Step 1: Update LDAP Bind Credentials**

Edit the file `00-rec-with-ldap.yaml` and replace the admin password:

```bash
# Open the file
vi security/ldap-ad-integration/00-rec-with-ldap.yaml

# Find line 13 and replace:
# password: "REPLACE_WITH_ADMIN_PASSWORD"
# with your actual Administrator password
```

### **Step 2: Deploy Redis Enterprise Cluster with LDAP**

Deploy the REC with LDAP configuration:

```bash
# Deploy REC with LDAP
kubectl apply -f security/ldap-ad-integration/00-rec-with-ldap.yaml
```

**Expected output:**
```
secret/ldap-bind-credentials created
redisenterprisecluster.app.redislabs.com/rec created
```

### **Step 3: Wait for REC to be Ready**

```bash
kubectl get rec -n redis-enterprise -w
```

**Expected output:**
```
NAME   NODES   VERSION      STATE     SPEC STATUS   LICENSE STATE   SHARDS LIMIT   LICENSE EXPIRATION DATE   AGE
rec    3       7.4.2-54     Running   Valid         Valid           4              2025-12-31                 5m
```

**Verify all pods are running:**
```bash
kubectl get pods -n redis-enterprise
```

**Expected output:**
```
NAME                                READY   STATUS    RESTARTS   AGE
rec-0                               2/2     Running   0          5m
rec-1                               2/2     Running   0          4m
rec-2                               2/2     Running   0          3m
redis-enterprise-operator-xxx       2/2     Running   0          10m
```

### **Step 4: Verify LDAP Configuration**

```bash
# Check LDAP configuration
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config | grep ldap
```

**Expected output:**
```
ldap_enabled: true
ldap_server: 3.83.144.166:389
```

### **Step 5: Map LDAP Groups to Redis Roles**

**Option A: Using Cluster Manager UI**

1. Get the UI service:
```bash
kubectl get svc -n redis-enterprise | grep ui
```

2. Port-forward to access UI:
```bash
kubectl port-forward svc/rec-ui 8443:8443 -n redis-enterprise
```

3. Open browser: https://localhost:8443

4. Login with admin credentials

5. Navigate to: **Access Control → LDAP Mappings → Create LDAP Mapping**

6. Create mappings:

**Mapping 1: Redis-Admins**
- **Unique mapping name:** redis-admins-mapping
- **Distinguished Name:** CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local
- **Role:** DB Admin (or Cluster Admin for full cluster access)

**Mapping 2: Redis-Developers**
- **Unique mapping name:** redis-developers-mapping
- **Distinguished Name:** CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local
- **Role:** DB Member

**Mapping 3: Redis-Viewers**
- **Unique mapping name:** redis-viewers-mapping
- **Distinguished Name:** CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local
- **Role:** DB Viewer

**Option B: Using Redis Enterprise API**

```bash
# Get API endpoint
API_URL="https://$(kubectl get svc rec -n redis-enterprise -o jsonpath='{.spec.clusterIP}'):9443"

# Get admin credentials
ADMIN_USER=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

# Create LDAP mapping for Redis-Admins
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-admins-mapping",
    "dn": "CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Admin"
  }'

# Create LDAP mapping for Redis-Developers
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-developers-mapping",
    "dn": "CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Member"
  }'

# Create LDAP mapping for Redis-Viewers
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
  "$API_URL/v1/ldap_mappings" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-viewers-mapping",
    "dn": "CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local",
    "role": "DB Viewer"
  }'
```

### **Step 6: Create Database with LDAP Authentication**

```bash
kubectl apply -f security/ldap-ad-integration/02-database-ldap-auth.yaml
```

**Expected output:**
```
redisenterprisedatabase.app.redislabs.com/redis-db-ldap created
redisenterprisedatabase.app.redislabs.com/redis-db-mixed-auth created
```

### **Step 7: Wait for Database to be Ready**

```bash
kubectl get redb -n redis-enterprise -w
```

**Expected output:**
```
NAME                STATUS   AGE
redis-db-ldap       active   1m
redis-db-mixed-auth active   1m
```

---

## 🧪 Testing

### **Test 1: Network Connectivity**

```bash
# Test connection to LDAP server
kubectl exec -it rec-0 -n redis-enterprise -- \
  nc -zv 3.83.144.166 389
```

**Expected output:**
```
Connection to 3.83.144.166 389 port [tcp/ldap] succeeded!
```

### **Test 2: LDAP Bind**

```bash
# Test LDAP bind with Administrator
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "DC=redis,DC=training,DC=local" \
  "(objectClass=user)" cn
```

**Expected output:**
```
# redis-admin, Users, redis.training.local
dn: CN=redis-admin,CN=Users,DC=redis,DC=training,DC=local
cn: redis-admin
...
result: 0 Success
```

### **Test 3: Search for Specific User**

```bash
# Search for redis-admin user
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "DC=redis,DC=training,DC=local" \
  "(&(objectClass=user)(sAMAccountName=redis-admin))" cn
```

### **Test 4: Verify Group Membership**

```bash
# Check if redis-admin is in Redis-Admins group
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local" \
  "(member=CN=redis-admin,CN=Users,DC=redis,DC=training,DC=local)"
```

### **Test 5: Verify LDAP is Enabled**

```bash
# Check LDAP configuration
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config | grep ldap
```

**Expected output:**
```
ldap_enabled: true
ldap_server: 3.83.144.166:389
```

### **Test 6: Get Database Service Endpoint**

```bash
# Get service details
kubectl get svc -n redis-enterprise | grep redis-db-ldap
```

**Expected output:**
```
redis-db-ldap   ClusterIP   10.x.x.x   <none>   12000/TCP   5m
```

### **Test 7: Test with redis-admin (Full Access)**

```bash
# Port-forward to access from local machine
kubectl port-forward svc/redis-db-ldap 12000:12000 -n redis-enterprise &

# Test PING
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  PING

# Test SET
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  SET test:admin "admin-value"

# Test GET
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  GET test:admin
```

**Expected output:**
```
PONG
OK
"admin-value"
```

### **Test 8: Test with redis-dev1 (Read/Write, No Dangerous)**

```bash
# Test SET (should work)
redis-cli -h localhost -p 12000 \
  --user redis-dev1 \
  --pass RedisDev123! \
  SET test:dev "dev-value"

# Test FLUSHALL (should fail - dangerous command)
redis-cli -h localhost -p 12000 \
  --user redis-dev1 \
  --pass RedisDev123! \
  FLUSHALL
```

**Expected output:**
```
OK
(error) NOPERM this user has no permissions to run the 'flushall' command
```

### **Test 9: Test with redis-viewer1 (Read-Only)**

```bash
# Test GET (should work)
redis-cli -h localhost -p 12000 \
  --user redis-viewer1 \
  --pass RedisView123! \
  GET test:admin

# Test SET (should fail - read-only)
redis-cli -h localhost -p 12000 \
  --user redis-viewer1 \
  --pass RedisView123! \
  SET test:viewer "viewer-value"
```

**Expected output:**
```
"admin-value"
(error) NOPERM this user has no permissions to run the 'set' command
```

### **Test 10: Verify User Permissions**

```bash
# Check who you are
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  ACL WHOAMI

# List ACL rules
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  ACL LIST
```

### **Test 11: Test from Python Application**

```python
import redis

# Test with redis-dev1
r = redis.Redis(
    host='localhost',
    port=12000,
    username='redis-dev1',
    password='RedisDev123!',
    decode_responses=True
)

# Test connection
print(r.ping())  # Should print: True

# Test write
r.set('app:key', 'value')
print(r.get('app:key'))  # Should print: value

# Test dangerous command (should fail)
try:
    r.flushall()
except redis.exceptions.ResponseError as e:
    print(f"Expected error: {e}")
```

### **Test 12: Test Authentication Failure**

```bash
# Test with wrong password
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass WrongPassword \
  PING
```

**Expected output:**
```
(error) WRONGPASS invalid username-password pair or user is disabled
```

---

## 🔍 Troubleshooting

### **Issue 1: Authentication Failed**

**Symptoms:**
```
(error) WRONGPASS invalid username-password pair or user is disabled
```

**Solutions:**

1. **Check LDAP logs:**
```bash
kubectl logs rec-0 -n redis-enterprise -c redis-enterprise-node | grep -i ldap
```

2. **Verify LDAP is enabled:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  rladmin cluster config | grep ldap
```

**Expected output:**
```
ldap_enabled: true
ldap_server: 3.83.144.166:389
```

3. **Check LDAP bind credentials secret:**
```bash
kubectl get secret ldap-bind-credentials -n redis-enterprise -o yaml
```

4. **Verify REC LDAP configuration:**
```bash
kubectl get rec rec -n redis-enterprise -o yaml | grep -A 20 ldap
```

### **Issue 2: Cannot Connect to LDAP Server**

**Symptoms:**
```
ldap_sasl_bind(SIMPLE): Can't contact LDAP server (-1)
```

**Solutions:**

1. **Test network connectivity:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  nc -zv 3.83.144.166 389
```

2. **Test DNS resolution:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  nslookup 3.83.144.166
```

3. **Check firewall rules:**
- Ensure port 389 (LDAP) or 636 (LDAPS) is open
- Check security groups on AWS EC2 instance

4. **Test LDAP query manually:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "DC=redis,DC=training,DC=local" \
  "(objectClass=user)"
```

### **Issue 3: User Not Found**

**Symptoms:**
```
testsaslauthd: authentication failed
```

**Solutions:**

1. **Verify user exists in AD:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "DC=redis,DC=training,DC=local" \
  "(&(objectClass=user)(sAMAccountName=redis-admin))"
```

2. **Check search filter:**
- Ensure `search_filter` in config is: `(&(objectClass=user)(sAMAccountName=%u))`

3. **Check user DN template:**
- Ensure `user_dn_template` is: `CN=%u,CN=Users,DC=redis,DC=training,DC=local`

### **Issue 4: Wrong Permissions**

**Symptoms:**
```
(error) NOPERM this user has no permissions to run the 'set' command
```

**Solutions:**

1. **Check ACL rules in database:**
```bash
kubectl get redb redis-db-ldap -n redis-enterprise -o yaml | grep -A 20 aclRules
```

2. **Verify user ACL:**
```bash
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  ACL LIST
```

3. **Update ACL rules:**
- Edit `02-database-ldap-auth.yaml`
- Apply changes: `kubectl apply -f 02-database-ldap-auth.yaml`

### **Issue 5: Database Not Ready**

**Symptoms:**
```
kubectl get redb -n redis-enterprise
NAME              STATUS    AGE
redis-db-ldap     pending   5m
```

**Solutions:**

1. **Check database events:**
```bash
kubectl describe redb redis-db-ldap -n redis-enterprise
```

2. **Check REC logs:**
```bash
kubectl logs rec-0 -n redis-enterprise -c redis-enterprise-node
```

3. **Check operator logs:**
```bash
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator
```

### **Issue 6: LDAP Not Enabled**

**Symptoms:**
```
kubectl exec -it rec-0 -n redis-enterprise -- rladmin cluster config | grep ldap
ldap_enabled: false
```

**Solutions:**

1. **Check REC LDAP configuration:**
```bash
kubectl get rec rec -n redis-enterprise -o yaml | grep -A 20 ldap
```

2. **Verify the ldap section exists in REC spec:**
```yaml
spec:
  ldap:
    protocol: LDAP
    servers:
      - host: 3.83.144.166
        port: 389
    enabledForControlPlane: true
    enabledForDataPlane: true
```

3. **If missing, update the REC:**
```bash
kubectl edit rec rec -n redis-enterprise
# Add the ldap section to spec
```

### **Issue 7: Bind DN or Password Incorrect**

**Symptoms:**
```
ldap_bind: Invalid credentials (49)
```

**Solutions:**

1. **Verify bind DN:**
```
CN=Administrator,CN=Users,DC=redis,DC=training,DC=local
```

2. **Test bind manually:**
```bash
kubectl exec -it rec-0 -n redis-enterprise -- \
  ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YOUR_ADMIN_PASSWORD" \
  -b "DC=redis,DC=training,DC=local" \
  "(objectClass=user)"
```

3. **Update secret with correct password:**
```bash
# Edit the secret
kubectl edit secret ldap-bind-credentials -n redis-enterprise

# Or delete and recreate
kubectl delete secret ldap-bind-credentials -n redis-enterprise
# Edit 00-rec-with-ldap.yaml with correct password (line 13)
kubectl apply -f 00-rec-with-ldap.yaml
```

---

## 📚 Summary

**What you configured:**
1. ✅ Redis Enterprise Cluster with LDAP integration
2. ✅ Samba Active Directory integration (redis.training.local)
3. ✅ LDAP authentication for Control Plane (Cluster Manager UI)
4. ✅ LDAP authentication for Data Plane (Database access)
5. ✅ LDAP group mappings to Redis roles
6. ✅ ACL rules for database access
7. ✅ 6 users with different access levels
8. ✅ 3 security groups (Admins, Developers, Viewers)

**LDAP Configuration:**
- **Protocol:** LDAP (port 389) or LDAPS (port 636)
- **Server:** 3.83.144.166
- **Base DN:** DC=redis,DC=training,DC=local
- **Bind DN:** CN=Administrator,CN=Users,DC=redis,DC=training,DC=local
- **Authentication Template:** CN=%u,CN=Users,DC=redis,DC=training,DC=local
- **Authorization Attribute:** memberOf

**Users and Access:**
- **redis-admin:** Full access (allkeys +@all) - Group: Redis-Admins
- **redis-dev1, redis-dev2:** Read/Write, no dangerous commands - Group: Redis-Developers
- **redis-viewer1, redis-viewer2, redis-readonly:** Read-only - Group: Redis-Viewers

**Files:**
- **00-rec-with-ldap.yaml:** REC with LDAP configuration
- **02-database-ldap-auth.yaml:** Databases with LDAP authentication
- **README.md:** Complete step-by-step guide

**Next Steps:**
- Test LDAP authentication with all users
- Set up monitoring for authentication failures
- Configure LDAPS (SSL/TLS) for production
- Test failover scenarios
- Document LDAP group mappings

---

## 🔗 References

- [Redis Enterprise LDAP Documentation](https://redis.io/docs/latest/operate/rs/security/access-control/ldap/)
- [SASLAUTHD Documentation](https://www.cyrusimap.org/sasl/sasl/auxprop.html)
- [Samba Active Directory](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller)

