# Quick Start Guide

This guide provides the **correct sequence** for deploying Redis Enterprise on Kubernetes.

---

## Choose Your Platform

Select your Kubernetes platform for platform-specific setup:

- **Amazon EKS:** [platforms/eks/README.md](platforms/eks/README.md)
- **Google GKE:** [platforms/gke/README.md](platforms/gke/README.md)
- **Azure AKS:** [platforms/aks/README.md](platforms/aks/README.md)
- **Red Hat OpenShift:** [platforms/openshift/README.md](platforms/openshift/README.md)
- **Vanilla Kubernetes:** [platforms/vanilla/README.md](platforms/vanilla/README.md)

---

## Generic Installation Order

Follow this order for any Kubernetes platform:

### 1. Platform-Specific Setup (5-10 min) 🔧

Configure platform-specific requirements:

- **EKS:** Storage (EBS CSI, gp3) → [platforms/eks/storage/README.md](platforms/eks/storage/README.md)
- **GKE:** Storage (GCE PD) → [platforms/gke/storage/README.md](platforms/gke/storage/README.md)
- **AKS:** Storage (Azure Disk) → [platforms/aks/storage/README.md](platforms/aks/storage/README.md)
- **OpenShift:** SCC → [platforms/openshift/scc/README.md](platforms/openshift/scc/README.md)
- **Vanilla:** Ensure storage class available

---

### 2. Redis Enterprise Operator (10 min) 🔧

**See:** [operator/README.md](operator/README.md)

Generic operator installation (works on all platforms).

---

### 3. Redis Enterprise Cluster & Database (20 min) 🗄️

**See:** [deployments/single-region/README.md](deployments/single-region/README.md)

Generic deployment (works on all platforms):
1. Deploy Redis Enterprise Cluster (REC)
2. Create test database (REDB)

---

### 4. Networking (Optional - 20 min) 🌐

Configure external access based on your platform:

- **Generic (EKS/GKE/AKS/Vanilla):** [networking/gateway-api/nginx-gateway-fabric/README.md](networking/gateway-api/nginx-gateway-fabric/README.md)
- **OpenShift:** [platforms/openshift/routes/README.md](platforms/openshift/routes/README.md)

---

### 5. Monitoring (Optional - 15 min) 📊

**See:** [monitoring/prometheus/README.md](monitoring/prometheus/README.md)

Generic monitoring setup (works on all platforms).

---

### 6. Admission Controller (Optional - 5 min) ✅

**See:** [operator/configuration/admission-controller/README.md](operator/configuration/admission-controller/README.md)

Generic admission controller setup (works on all platforms).

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
- [Deployment](deployments/single-region/README.md#troubleshooting)
- [Monitoring](monitoring/prometheus/README.md#troubleshooting)
- [Networking](networking/gateway-api/nginx-gateway-fabric/README.md#troubleshooting)
- [Platform-Specific](platforms/)

