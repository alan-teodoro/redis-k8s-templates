# OpenShift Security Context Constraints (SCC)

OpenShift-specific security configuration for Redis Enterprise.

---

## Overview

OpenShift uses Security Context Constraints (SCC) to control pod permissions.
Redis Enterprise requires specific SCC to run properly.

---

## Files

| File | Description |
|------|-------------|
| `redis-scc.yaml` | Custom SCC for Redis Enterprise |

---

## Prerequisites

- OpenShift cluster with admin access
- Redis Enterprise Operator installed

---

## Deployment

### 1. Apply SCC

```bash
oc apply -f redis-scc.yaml
```

### 2. Verify SCC

```bash
oc get scc redis-enterprise-scc
```

### 3. Bind SCC to Service Account

The SCC is automatically bound to the `redis-enterprise-operator` service account.

Verify:

```bash
oc describe scc redis-enterprise-scc
```

---

## What This SCC Allows

- **Run as any user:** Required for Redis Enterprise processes
- **FSGroup:** Required for persistent volume permissions
- **Capabilities:** Required for network operations
- **Host ports:** Required for cluster communication

---

## Troubleshooting

### Pods Not Starting

Check if SCC is applied:

```bash
oc get scc redis-enterprise-scc
```

Check pod security context:

```bash
oc describe pod rec-0 -n redis-enterprise | grep -A 10 "Security Context"
```

### Permission Denied Errors

Verify service account has SCC:

```bash
oc describe scc redis-enterprise-scc | grep Users
```

Should show: `system:serviceaccount:redis-enterprise:redis-enterprise-operator`

---

## References

- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Redis Enterprise on OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)

