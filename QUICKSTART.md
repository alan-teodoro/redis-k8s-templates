# Quick Start Guide

This guide provides the **correct sequence** for deploying Redis Enterprise on Kubernetes.

Each section references detailed documentation for more information.

---

## Prerequisites

- ✅ Kubernetes cluster running (EKS, GKE, AKS, or on-premises)
- ✅ `kubectl` configured and connected to cluster
- ✅ `helm` installed (v3.x)
- ✅ Cluster admin permissions

---

## Installation Order

### 1. Storage Configuration (5 min) 📦

**See:** [platforms/eks/storage/README.md](platforms/eks/storage/README.md)

Follow the instructions in the README to configure storage for your platform.

**For other platforms:** Check `platforms/<your-platform>/storage/`

---

### 2. Redis Enterprise Operator (10 min) 🔧

**See:** [operator/README.md](operator/README.md)

Follow the installation instructions in the README.

---

### 3. Redis Enterprise Cluster & Database (20 min) 🗄️

**See:** [examples/basic-deployment/README.md](examples/basic-deployment/README.md)

Follow the deployment instructions in the README to:
1. Deploy Redis Enterprise Cluster (REC)
2. Create test database (REDB)

---

### 4. Monitoring (Optional - 15 min) 📊

**See:** [monitoring/prometheus/README.md](monitoring/prometheus/README.md)

Follow the monitoring setup instructions in the README.

---

### 5. Admission Controller (Optional - 5 min) ✅

**See:** [operator/configuration/admission-controller/README.md](operator/configuration/admission-controller/README.md)

Follow the admission controller setup instructions in the README.

---

### 6. Networking - Gateway API (Optional - 20 min) 🌐

**See:** [networking/gateway-api/nginx-gateway-fabric/README.md](networking/gateway-api/nginx-gateway-fabric/README.md)

Follow the Gateway API setup instructions in the README for:
- REC UI access via HTTPRoute (HTTPS with TLS termination)
- Database access via TLSRoute (TLS passthrough)

---

## Verification Commands

```bash
# Check all Redis Enterprise resources
kubectl get rec,redb -n redis-enterprise

# Check operator logs
kubectl logs -n redis-enterprise -l name=redis-enterprise-operator --tail=50

# Check cluster status
kubectl describe rec rec -n redis-enterprise

# Check database status
kubectl describe redb test-db -n redis-enterprise

# Check services
kubectl get svc -n redis-enterprise
```

---

## Next Steps

- **Production Setup**: See [deployments/production/](deployments/production/)
- **Security**: See [security/](security/)
- **Backup/Restore**: See [backup-restore/](backup-restore/)
- **Active-Active**: See [deployments/active-active/](deployments/active-active/)

---

## Troubleshooting

See individual component READMEs for detailed troubleshooting:
- [Operator](operator/README.md#troubleshooting)
- [Deployment](examples/basic-deployment/README.md#troubleshooting)
- [Monitoring](monitoring/prometheus/README.md#troubleshooting)
- [Networking](networking/gateway-api/nginx-gateway-fabric/README.md#troubleshooting)

