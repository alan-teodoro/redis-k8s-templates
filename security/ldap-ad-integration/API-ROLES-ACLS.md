# Redis Enterprise API - Create Roles and ACLs for LDAP Authentication

This guide shows how to create Redis Enterprise Roles and ACLs using the REST API to enable LDAP authentication for databases.

## ⚠️ Why Use the API?

**IMPORTANT:** Redis Enterprise on Kubernetes **does NOT support** configuring LDAP Roles and ACLs via Kubernetes YAML manifests.

**What you CANNOT do in YAML:**
- ❌ Create ACLs (Access Control Lists) in RedisEnterpriseDatabase CRD
- ❌ Create Roles in RedisEnterpriseCluster CRD
- ❌ Map LDAP groups to Roles in Kubernetes manifests
- ❌ Bind Roles to ACLs for databases in YAML

**What you MUST do via API or UI:**
- ✅ Create ACLs using REST API or Redis Enterprise UI
- ✅ Create Roles using REST API or Redis Enterprise UI
- ✅ Map LDAP groups to Roles using REST API or Redis Enterprise UI
- ✅ Bind Roles to ACLs for databases using REST API or Redis Enterprise UI

**Why?**
- The RedisEnterpriseDatabase CRD has a `rolesPermissions` field, but it only references existing Roles and ACLs
- Roles and ACLs must be created first via the Redis Enterprise API or UI
- LDAP group mappings are stored in the Redis Enterprise cluster configuration, not in Kubernetes resources

**Reference:**
- [Redis Enterprise LDAP Documentation](https://redis.io/docs/latest/operate/kubernetes/security/ldap/)
- Quote: *"To map LDAP groups to Redis Enterprise access control roles, you'll need to use the Redis Enterprise API or admin console."*

## Prerequisites

- Redis Enterprise Cluster deployed and running
- LDAP configured in the REC (see `00-rec-with-ldap.yaml`)
- Database deployed (see `01-database-ldap-auth.yaml`)
- Access to Redis Enterprise API
- `curl` and `jq` installed

## API Authentication

Get the admin credentials:
```bash
# Get admin username
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.username}' | base64 -d

# Get admin password
kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

Port-forward to the API:
```bash
kubectl port-forward svc/rec 9443:9443 -n redis-enterprise
```

API Base URL: `https://localhost:9443/v1`

## Step 1: Create ACLs (Access Control Lists)

ACLs define the Redis permissions (commands, keys, etc.).

### Create Admin ACL (Full Access)
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/acls \
  -H "Content-Type: application/json" \
  -d '{
    "name": "admin-acl",
    "acl": "allkeys +@all"
  }'
```

### Create Developer ACL (Read/Write, No Dangerous Commands)
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/acls \
  -H "Content-Type: application/json" \
  -d '{
    "name": "developer-acl",
    "acl": "allkeys +@all -@dangerous"
  }'
```

### Create Viewer ACL (Read-Only)
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/acls \
  -H "Content-Type: application/json" \
  -d '{
    "name": "viewer-acl",
    "acl": "allkeys +@read"
  }'
```

### List ACLs
```bash
curl -k -u "<admin-user>:<admin-password>" \
  https://localhost:9443/v1/acls
```

## Step 2: Create Roles and Map to LDAP Groups

Roles map LDAP groups to Redis Enterprise access control.

### Create Redis-Admins Role
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/roles \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-admins-role",
    "management": "admin",
    "ldap_groups": [
      "CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local"
    ]
  }'
```

### Create Redis-Developers Role
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/roles \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-developers-role",
    "management": "db_member",
    "ldap_groups": [
      "CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local"
    ]
  }'
```

### Create Redis-Viewers Role
```bash
curl -k -u "<admin-user>:<admin-password>" \
  -X POST https://localhost:9443/v1/roles \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-viewers-role",
    "management": "db_viewer",
    "ldap_groups": [
      "CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local"
    ]
  }'
```

### List Roles
```bash
curl -k -u "<admin-user>:<admin-password>" \
  https://localhost:9443/v1/roles
```

## Step 3: Get Database UID

You need the database UID to bind roles to ACLs.

```bash
curl -k -u "<admin-user>:<admin-password>" \
  https://localhost:9443/v1/bdbs | jq '.[] | select(.name=="redis-db-ldap") | .uid'
```

Save the UID (e.g., `1`, `2`, etc.)

## Step 4: Bind Roles to ACLs for the Database

Update the database to use the roles and ACLs.

```bash
# Replace <DB_UID> with the UID from Step 3
curl -k -u "<admin-user>:<admin-password>" \
  -X PUT https://localhost:9443/v1/bdbs/<DB_UID> \
  -H "Content-Type: application/json" \
  -d '{
    "roles_permissions": [
      {
        "role_uid": 1,
        "redis_acl_uid": 1
      },
      {
        "role_uid": 2,
        "redis_acl_uid": 2
      },
      {
        "role_uid": 3,
        "redis_acl_uid": 3
      }
    ]
  }'
```

**Note:** You need to get the actual `role_uid` and `redis_acl_uid` from the previous API calls.

### Get Role UIDs
```bash
curl -k -u "<admin-user>:<admin-password>" \
  https://localhost:9443/v1/roles | jq '.[] | {name: .name, uid: .uid}'
```

### Get ACL UIDs
```bash
curl -k -u "<admin-user>:<admin-password>" \
  https://localhost:9443/v1/acls | jq '.[] | {name: .name, uid: .uid}'
```

## Step 5: Test LDAP Authentication

After configuring roles and ACLs, test LDAP authentication.

### Port-forward to Database
```bash
kubectl port-forward svc/redis-db-ldap 12000:12000 -n redis-enterprise
```

### Test with redis-admin (Full Access)
```bash
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  PING
```
**Expected:** `PONG`

### Test Write with redis-admin
```bash
redis-cli -h localhost -p 12000 \
  --user redis-admin \
  --pass RedisAdmin123! \
  SET test:admin "admin-value"
```
**Expected:** `OK`

### Test with redis-dev1 (Developer)
```bash
redis-cli -h localhost -p 12000 \
  --user redis-dev1 \
  --pass RedisDev123! \
  SET test:dev "dev-value"
```
**Expected:** `OK`

### Test Dangerous Command with redis-dev1 (Should Fail)
```bash
redis-cli -h localhost -p 12000 \
  --user redis-dev1 \
  --pass RedisDev123! \
  FLUSHALL
```
**Expected:** `(error) NOPERM this user has no permissions to run the 'flushall' command`

### Test with redis-viewer1 (Read-Only)
```bash
redis-cli -h localhost -p 12000 \
  --user redis-viewer1 \
  --pass RedisView123! \
  GET test:admin
```
**Expected:** `"admin-value"`

### Test Write with redis-viewer1 (Should Fail)
```bash
redis-cli -h localhost -p 12000 \
  --user redis-viewer1 \
  --pass RedisView123! \
  SET test:fail "value"
```
**Expected:** `(error) NOPERM this user has no permissions to run the 'set' command`

## Complete Example Script

Here's a complete bash script to automate the entire process:

```bash
#!/bin/bash

# Configuration
NAMESPACE="redis-enterprise"
REC_NAME="rec"
DB_NAME="redis-db-ldap"
API_URL="https://localhost:9443/v1"

# Get admin credentials
ADMIN_USER=$(kubectl get secret $REC_NAME -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret $REC_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)

echo "Admin User: $ADMIN_USER"

# Port-forward to API (run in background)
kubectl port-forward svc/$REC_NAME 9443:9443 -n $NAMESPACE &
PF_PID=$!
sleep 3

# Create ACLs
echo "Creating ACLs..."
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/acls -H "Content-Type: application/json" \
  -d '{"name": "admin-acl", "acl": "allkeys +@all"}'

curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/acls -H "Content-Type: application/json" \
  -d '{"name": "developer-acl", "acl": "allkeys +@all -@dangerous"}'

curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/acls -H "Content-Type: application/json" \
  -d '{"name": "viewer-acl", "acl": "allkeys +@read"}'

# Create Roles
echo "Creating Roles..."
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/roles -H "Content-Type: application/json" \
  -d '{
    "name": "redis-admins-role",
    "management": "admin",
    "ldap_groups": ["CN=Redis-Admins,CN=Users,DC=redis,DC=training,DC=local"]
  }'

curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/roles -H "Content-Type: application/json" \
  -d '{
    "name": "redis-developers-role",
    "management": "db_member",
    "ldap_groups": ["CN=Redis-Developers,CN=Users,DC=redis,DC=training,DC=local"]
  }'

curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X POST $API_URL/roles -H "Content-Type: application/json" \
  -d '{
    "name": "redis-viewers-role",
    "management": "db_viewer",
    "ldap_groups": ["CN=Redis-Viewers,CN=Users,DC=redis,DC=training,DC=local"]
  }'

# Get UIDs
echo "Getting UIDs..."
ADMIN_ACL_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/acls | jq '.[] | select(.name=="admin-acl") | .uid')
DEV_ACL_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/acls | jq '.[] | select(.name=="developer-acl") | .uid')
VIEW_ACL_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/acls | jq '.[] | select(.name=="viewer-acl") | .uid')

ADMIN_ROLE_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/roles | jq '.[] | select(.name=="redis-admins-role") | .uid')
DEV_ROLE_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/roles | jq '.[] | select(.name=="redis-developers-role") | .uid')
VIEW_ROLE_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/roles | jq '.[] | select(.name=="redis-viewers-role") | .uid')

DB_UID=$(curl -sk -u "$ADMIN_USER:$ADMIN_PASS" $API_URL/bdbs | jq ".[] | select(.name==\"$DB_NAME\") | .uid")

echo "ACL UIDs: admin=$ADMIN_ACL_UID, dev=$DEV_ACL_UID, view=$VIEW_ACL_UID"
echo "Role UIDs: admin=$ADMIN_ROLE_UID, dev=$DEV_ROLE_UID, view=$VIEW_ROLE_UID"
echo "Database UID: $DB_UID"

# Bind Roles to ACLs
echo "Binding Roles to ACLs for database..."
curl -k -u "$ADMIN_USER:$ADMIN_PASS" -X PUT $API_URL/bdbs/$DB_UID -H "Content-Type: application/json" \
  -d "{
    \"roles_permissions\": [
      {\"role_uid\": $ADMIN_ROLE_UID, \"redis_acl_uid\": $ADMIN_ACL_UID},
      {\"role_uid\": $DEV_ROLE_UID, \"redis_acl_uid\": $DEV_ACL_UID},
      {\"role_uid\": $VIEW_ROLE_UID, \"redis_acl_uid\": $VIEW_ACL_UID}
    ]
  }"

echo "Done! LDAP authentication configured."

# Cleanup
kill $PF_PID
```

Save this script as `configure-ldap-roles.sh` and run:
```bash
chmod +x configure-ldap-roles.sh
./configure-ldap-roles.sh
```

## API Reference

- **Redis Enterprise REST API Documentation**: https://redis.io/docs/latest/operate/rs/references/rest-api/
- **ACLs API**: https://redis.io/docs/latest/operate/rs/references/rest-api/requests/acls/
- **Roles API**: https://redis.io/docs/latest/operate/rs/references/rest-api/requests/roles/
- **Databases API**: https://redis.io/docs/latest/operate/rs/references/rest-api/requests/bdbs/

## Troubleshooting

### Check LDAP Configuration
```bash
kubectl exec -it rec-0 -n redis-enterprise -- rladmin cluster config | grep ldap
```

### Check Database Configuration
```bash
curl -k -u "$ADMIN_USER:$ADMIN_PASS" https://localhost:9443/v1/bdbs/<DB_UID> | jq .
```

### View Logs
```bash
kubectl logs rec-0 -n redis-enterprise -c redis-enterprise-node | grep -i ldap
```

### Test LDAP Connection from Pod
```bash
kubectl exec -it rec-0 -n redis-enterprise -- ldapsearch -x -H ldap://3.83.144.166:389 \
  -D "CN=Administrator,CN=Users,DC=redis,DC=training,DC=local" \
  -w "YourPassword" \
  -b "CN=Users,DC=redis,DC=training,DC=local" \
  "(sAMAccountName=redis-admin)"
```

