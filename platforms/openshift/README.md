# Redis Enterprise on OpenShift

Redis Enterprise deployment guide for Red Hat OpenShift.

---

## Overview

OpenShift-specific configurations and guides for deploying Redis Enterprise.

**Key Differences from Generic Kubernetes:**
- Uses **Routes** instead of Ingress/Gateway API (native)
- Requires **Security Context Constraints (SCC)**
- Integrated with OpenShift monitoring and logging

---

## Directory Structure

```
platforms/openshift/
├── README.md                   # This file
├── single-region/              # Complete OpenShift example (OpenShift-specific)
│   ├── README.md
│   ├── 00-namespace.yaml
│   ├── 01-rec-admin-secret.yaml
│   ├── 02-rec.yaml
│   ├── 03-redb-secret.yaml
│   └── 04-redb.yaml
├── scc/                        # Security Context Constraints (OpenShift-specific)
│   ├── README.md
│   └── redis-scc.yaml
├── routes/                     # Routes for external access (OpenShift-specific)
│   ├── README.md
│   ├── route-ui.yaml
│   └── route-db.yaml
└── active-active/              # Multi-cluster Active-Active (OpenShift-specific)
    ├── README.md
    ├── clusterA/
    └── clusterB/
```

**Deployment Options:**
- **OpenShift-Specific (Recommended):** [single-region/README.md](single-region/README.md) - Complete example with Routes, secrets, OpenShift configurations
- **Generic (Alternative):** [../../deployments/single-region/README.md](../../deployments/single-region/README.md) - Works on any Kubernetes

**Generic configurations:**
- **Operator:** [../../operator/README.md](../../operator/README.md)
- **Monitoring:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

---

## Quick Start

**Two deployment options:**

1. **OpenShift-Specific (Recommended):** [single-region/README.md](single-region/README.md) - Complete example with Routes, secrets, and OpenShift configurations
2. **Generic (Below):** Use generic Kubernetes deployment with OpenShift-specific Routes

---

### Prerequisites

- OpenShift 4.10+ cluster
- Cluster admin access (`oc` configured)
- Default storage class available

### Installation Steps

#### 1. Apply SCC (OpenShift-Specific)

**See:** [scc/README.md](scc/README.md)

```bash
oc apply -f scc/redis-scc.yaml
```

#### 2. Install Operator (Generic)

**See:** [../../operator/README.md](../../operator/README.md)

Install via OperatorHub or Helm:

```bash
helm repo add redis https://helm.redis.io
helm install redis-operator redis/redis-enterprise-operator \
  --version 8.0.6-8 \
  -n redis-enterprise \
  --create-namespace
```

#### 3. Deploy Cluster & Database (Generic)

**See:** [../../deployments/single-region/README.md](../../deployments/single-region/README.md)

```bash
# Create namespace
oc apply -f ../../deployments/single-region/00-namespace.yaml

# Apply RBAC
oc apply -f ../../deployments/single-region/01-rbac-rack-awareness.yaml

# Deploy REC
oc apply -f ../../deployments/single-region/02-rec.yaml

# Wait for ready
oc wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s

# Create database
oc apply -f ../../deployments/single-region/03-redb.yaml
```

#### 4. Create Routes (OpenShift-Specific)

**See:** [routes/README.md](routes/README.md)

```bash
# UI access
oc apply -f routes/route-ui.yaml

# Database access (optional)
oc apply -f routes/route-db.yaml

# Get UI URL
oc get route route-ui -n redis-enterprise -o jsonpath='{.spec.host}'
```

#### 5. Access REC UI

```bash
# Get URL
UI_URL=$(oc get route route-ui -n redis-enterprise -o jsonpath='{.spec.host}')

# Get password
PASSWORD=$(oc get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

# Open browser
echo "URL: https://$UI_URL"
echo "User: demo@redis.com"
echo "Pass: $PASSWORD"
```

---

## Active-Active Deployment

**See:** [active-active/README.md](active-active/README.md)

Multi-cluster geo-distributed deployment with conflict-free replication.

---

## Monitoring (Optional)

**See:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

Standard Prometheus monitoring works on OpenShift.

OpenShift-specific: Use built-in monitoring or deploy kube-prometheus-stack.

---

## Testing (Optional)

**See:** [../../testing/benchmarking/README.md](../../testing/benchmarking/README.md)

Standard benchmarking tools work on OpenShift.

---

## OpenShift-Specific Features

### Routes vs Ingress/Gateway API

OpenShift uses **Routes** (native) instead of Kubernetes Ingress or Gateway API.

**Advantages:**
- ✅ No additional installation required
- ✅ Integrated with OpenShift Router
- ✅ Automatic TLS termination
- ✅ Simple configuration

**See:** [routes/README.md](routes/README.md)

### Security Context Constraints (SCC)

OpenShift requires SCC for pod security instead of Pod Security Policies/Standards.

**See:** [scc/README.md](scc/README.md)

### Integrated Monitoring

OpenShift includes built-in monitoring. You can use:
- OpenShift built-in Prometheus
- Custom kube-prometheus-stack deployment

**See:** [../../monitoring/prometheus/README.md](../../monitoring/prometheus/README.md)

---

## References

- [Redis Enterprise on Kubernetes](https://redis.io/docs/latest/operate/kubernetes/)
- [Redis Enterprise on OpenShift](https://redis.io/docs/latest/operate/kubernetes/deployment/openshift/)
- [OpenShift Routes](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html)
- [OpenShift SCC](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)

