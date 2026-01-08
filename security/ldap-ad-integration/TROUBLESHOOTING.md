# LDAP/AD Integration Troubleshooting Guide

## 🔍 Problem Identified

**Error:** LDAP authentication failing with "invalid username-password pair"

**Log Evidence:**
```
2026-01-08 12:18:57,920 WARNING ldapia_auth_client: Cannot authenticate LDAP user redis-admin: invalid username-password pair
```

---

## 📋 Root Cause Analysis

Based on the logs analysis from `/var/opt/redislabs/log/cnm_http.log`, the issue is:

### **Possible Causes:**

1. ✅ **LDAP Agent is running** - Confirmed in logs
2. ✅ **LDAP configuration is loaded** - Confirmed in REC spec
3. ✅ **Bind credentials secret exists** - Confirmed
4. ❌ **User authentication failing** - This is the problem

### **Most Likely Issues:**

| Issue | Description | How to Check |
|-------|-------------|--------------|
| **Wrong password** | The password for `redis-admin` in AD is different | Verify in AD server |
| **User doesn't exist** | User `redis-admin` not created in AD | Check AD users |
| **Wrong DN template** | Authentication query template is incorrect | Verify user DN in AD |
| **LDAP server unreachable** | Network connectivity issue | Test from pod |
| **Bind credentials wrong** | Administrator password in secret is wrong | Verify in AD |

---

## 🔧 Diagnostic Steps

### **Step 1: Verify LDAP Configuration**

```bash
# Check REC LDAP config
kubectl get rec rec -n redis-enterprise -o yaml | grep -A 30 ldap
```

**Expected:**
```yaml
ldap:
  authenticationQuery:
    template: CN=%u,CN=Users,DC=redis,DC=training,DC=local
  authorizationQuery:
    attribute: memberOf
  bindCredentialsSecretName: ldap-bind-credentials
  enabledForControlPlane: true
  enabledForDataPlane: true
  protocol: LDAP
  servers:
  - host: 3.83.144.166
    port: 389
```

### **Step 2: Check Bind Credentials**

```bash
# Check bind DN
kubectl get secret ldap-bind-credentials -n redis-enterprise -o jsonpath='{.data.dn}' | base64 -d
# Expected: CN=Administrator,CN=Users,DC=redis,DC=training,DC=local

# Check bind password
kubectl get secret ldap-bind-credentials -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
# Expected: Your actual Administrator password
```

### **Step 3: Check LDAP Logs**

```bash
# Check LDAP agent logs
kubectl exec rec-0 -n redis-enterprise -- cat /var/opt/redislabs/log/ldap_agent_mgr.log

# Check authentication logs
kubectl exec rec-0 -n redis-enterprise -- tail -50 /var/opt/redislabs/log/cnm_http.log | grep -i ldap
```

### **Step 4: Verify User Exists in AD**

**On the Samba AD server:**

```bash
# SSH to AD server
ssh admin@3.83.144.166

# List all users
samba-tool user list | grep redis

# Check specific user
samba-tool user show redis-admin

# Verify user DN
ldapsearch -x -H ldap://localhost:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YourPassword" \
  -b "DC=redis,DC=training,DC=local" \
  "(sAMAccountName=redis-admin)"
```

### **Step 5: Test LDAP Bind from Pod**

```bash
# Install ldapsearch in pod (if available)
kubectl exec -it rec-0 -n redis-enterprise -- bash

# Test LDAP bind with Administrator
ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "RedisAdmin123!" \
  -b "DC=redis,DC=training,DC=local" \
  "(objectClass=user)"

# Test specific user
ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "RedisAdmin123!" \
  -b "DC=redis,DC=training,DC=local" \
  "(sAMAccountName=redis-admin)"
```

---

## ✅ Solutions

### **Solution 1: Verify User Credentials in AD**

The most common issue is that the user doesn't exist or has a different password.

**On AD Server:**
```bash
# Reset user password
samba-tool user setpassword redis-admin --newpassword="RedisAdmin123!"

# Verify user exists
samba-tool user show redis-admin
```

### **Solution 2: Update Bind Credentials**

If the Administrator password is wrong:

```bash
# Delete old secret
kubectl delete secret ldap-bind-credentials -n redis-enterprise

# Edit 00-rec-with-ldap.yaml with correct password (line 23)
vi security/ldap-ad-integration/00-rec-with-ldap.yaml

# Apply only the secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ldap-bind-credentials
  namespace: redis-enterprise
type: Opaque
stringData:
  dn: "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local"
  password: "YOUR_CORRECT_PASSWORD"
EOF

# Restart REC pods to pick up new secret
kubectl delete pod rec-0 -n redis-enterprise
```

### **Solution 3: Fix Authentication Query Template**

If the DN template is wrong:

```bash
# Check user's actual DN in AD
ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "Password" \
  -b "DC=redis,DC=training,DC=local" \
  "(sAMAccountName=redis-admin)" dn

# Update REC with correct template
kubectl edit rec rec -n redis-enterprise

# Change:
# authenticationQuery:
#   template: CN=%u,CN=Users,DC=redis,DC=training,DC=local
# To match the actual DN structure
```

---

## 📊 Monitoring Authentication Attempts

### **Real-time Log Monitoring**

```bash
# Terminal 1: Monitor authentication logs
kubectl exec -it rec-0 -n redis-enterprise -- tail -f /var/opt/redislabs/log/cnm_http.log | grep -i "ldap\|auth"

# Terminal 2: Try to login
# Open browser and try to login with LDAP user
```

### **Check Recent Failed Logins**

```bash
kubectl exec rec-0 -n redis-enterprise -- grep "Cannot authenticate LDAP" /var/opt/redislabs/log/cnm_http.log
```

---

## 🎯 Next Steps

1. ✅ **Verify user exists in AD** - Most critical
2. ✅ **Verify user password** - Test with ldapsearch
3. ✅ **Check bind credentials** - Administrator password
4. ✅ **Test LDAP connectivity** - From REC pod to AD server
5. ✅ **Check LDAP mappings** - Ensure groups are mapped

---

## 📞 Need Help?

If the issue persists, collect the following information:

```bash
# Collect all logs
kubectl exec rec-0 -n redis-enterprise -- cat /var/opt/redislabs/log/ldap_agent_mgr.log > ldap_agent.log
kubectl exec rec-0 -n redis-enterprise -- tail -200 /var/opt/redislabs/log/cnm_http.log > cnm_http.log
kubectl get rec rec -n redis-enterprise -o yaml > rec_config.yaml
kubectl get secret ldap-bind-credentials -n redis-enterprise -o yaml > bind_secret.yaml

# Create a tarball
tar -czf ldap-troubleshooting-$(date +%Y%m%d-%H%M%S).tar.gz *.log *.yaml
```

Share these logs for further analysis.

