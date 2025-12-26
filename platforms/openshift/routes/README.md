# OpenShift Routes for Redis Enterprise

OpenShift-specific networking using Routes (native ingress).

---

## Overview

OpenShift Routes provide native ingress capabilities without requiring external ingress controllers.

**Advantages:**
- ✅ Native to OpenShift (no additional installation)
- ✅ Automatic TLS termination
- ✅ Integrated with OpenShift Router
- ✅ Simple configuration

---

## Files

| File | Description |
|------|-------------|
| `route-ui.yaml` | Route for Redis Enterprise UI access |
| `route-db.yaml` | Route for database access (passthrough TLS) |

---

## Prerequisites

- Redis Enterprise Cluster deployed ([deployments/single-region/README.md](../../../deployments/single-region/README.md))
- OpenShift Router running (default in OpenShift)

---

## Deployment

### 1. Create Route for REC UI

```bash
oc apply -f route-ui.yaml
```

### 2. Create Route for Database (Optional)

```bash
oc apply -f route-db.yaml
```

### 3. Get URLs

```bash
# UI URL
oc get route route-ui -n redis-enterprise -o jsonpath='{.spec.host}'

# Database URL
oc get route route-db -n redis-enterprise -o jsonpath='{.spec.host}'
```

---

## Access REC UI

### Get URL

```bash
UI_URL=$(oc get route route-ui -n redis-enterprise -o jsonpath='{.spec.host}')
echo "REC UI: https://$UI_URL"
```

### Get Credentials

```bash
# Username
echo "demo@redis.com"

# Password
oc get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
```

### Open in Browser

```bash
open "https://$UI_URL"
```

---

## Access Database via Route

### Get Database Route

```bash
DB_HOST=$(oc get route route-db -n redis-enterprise -o jsonpath='{.spec.host}')
DB_PORT=443  # Routes use standard HTTPS port
```

### Get Database Password

```bash
DB_PASSWORD=$(oc get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)
```

### Test Connection

```bash
redis-cli -h $DB_HOST -p $DB_PORT --tls --sni $DB_HOST --insecure -a $DB_PASSWORD PING
```

**Expected:** `PONG`

---

## Route Configuration

### UI Route (TLS Termination)

- **Type:** Edge termination
- **TLS:** Terminated at router
- **Backend:** HTTP to rec-ui:8443

### Database Route (TLS Passthrough)

- **Type:** Passthrough
- **TLS:** Not terminated (passed through to backend)
- **Backend:** TLS to database service

---

## Troubleshooting

### Route Not Accessible

```bash
# Check route status
oc get route -n redis-enterprise

# Check router pods
oc get pods -n openshift-ingress

# Check route details
oc describe route route-ui -n redis-enterprise
```

### Certificate Errors

Routes use OpenShift's default wildcard certificate. For production, configure custom certificates:

```bash
oc create route edge route-ui \
  --service=rec-ui \
  --cert=tls.crt \
  --key=tls.key \
  --ca-cert=ca.crt \
  -n redis-enterprise
```

---

## References

- [OpenShift Routes Documentation](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)
- [Redis Enterprise on OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)

