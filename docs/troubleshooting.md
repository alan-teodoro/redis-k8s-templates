# Redis Enterprise on Kubernetes - Troubleshooting Guide

Quick reference for common issues and solutions.

## Operator Issues

### Operator Pod Not Starting

**Symptoms:**
- Operator pod in CrashLoopBackOff or Error state

**Check:**
```bash
kubectl get pods -n <operator-namespace>
kubectl logs -n <operator-namespace> <operator-pod-name>
```

**Common Causes:**
- Insufficient RBAC permissions
- Missing CRDs
- Resource constraints

**Solutions:**
- Verify RBAC: `kubectl get clusterrole redis-enterprise-operator`
- Reinstall CRDs: `kubectl apply -f <operator-crd-yaml>`
- Check node resources: `kubectl describe node`

---

### Operator Installed but REC Not Creating

**Symptoms:**
- REC resource created but no pods appear

**Check:**
```bash
kubectl describe rec <rec-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Common Causes:**
- Admission controller not configured
- Webhook issues
- Storage class not available

**Solutions:**
- Verify admission controller is running
- Check webhook configuration: `kubectl get validatingwebhookconfigurations`
- Verify storage class: `kubectl get storageclass`

---

## Redis Enterprise Cluster (REC) Issues

### REC Pods Not Starting

**Symptoms:**
- REC pods stuck in Pending or Init state

**Check:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <rec-pod-name> -n <namespace>
```

**Common Causes:**
- Insufficient resources
- PVC not binding
- Node affinity/taints
- Security constraints (OpenShift SCC)

**Solutions:**
- Check node resources: `kubectl top nodes`
- Check PVC status: `kubectl get pvc -n <namespace>`
- Verify storage class: `kubectl get sc`
- OpenShift: Verify SCC applied correctly

---

### REC Status Not Ready

**Symptoms:**
- REC exists but status shows not ready

**Check:**
```bash
kubectl get rec -n <namespace>
kubectl describe rec <rec-name> -n <namespace>
kubectl logs <rec-pod-name> -n <namespace>
```

**Common Causes:**
- Cluster formation issues
- Network connectivity between pods
- DNS resolution problems

**Solutions:**
- Check pod-to-pod connectivity
- Verify DNS: `kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>`
- Check network policies

---

## Database (REDB) Issues

### Database Not Creating

**Symptoms:**
- REDB resource created but database not available

**Check:**
```bash
kubectl describe redb <redb-name> -n <namespace>
kubectl get events -n <namespace>
```

**Common Causes:**
- REC not ready
- Insufficient cluster resources
- Invalid database configuration
- Secret not found

**Solutions:**
- Verify REC is ready: `kubectl get rec -n <namespace>`
- Check cluster resources via UI
- Verify secret exists: `kubectl get secret <secret-name> -n <namespace>`
- Check REDB spec for errors

---

### Cannot Connect to Database

**Symptoms:**
- Database shows ready but connection fails

**Check:**
```bash
# Get database service
kubectl get svc -n <namespace> | grep <redb-name>

# Test connectivity
kubectl run -it --rm redis-cli --image=redis:latest --restart=Never -- \
  redis-cli -h <service-name>.<namespace>.svc.cluster.local -p <port>
```

**Common Causes:**
- Service not created
- Network policies blocking traffic
- Incorrect credentials
- TLS configuration mismatch

**Solutions:**
- Verify service exists and has endpoints
- Check network policies: `kubectl get networkpolicies -n <namespace>`
- Verify credentials from secret
- Check TLS settings in REDB spec

---

## Active-Active Issues

### Remote Cluster Connection Failed

**Symptoms:**
- RERC (Remote Cluster) shows not connected

**Check:**
```bash
kubectl describe rerc <rerc-name> -n <namespace>
```

**Common Causes:**
- Network connectivity between clusters
- Incorrect API endpoint
- Invalid credentials
- Firewall blocking ports

**Solutions:**
- Test connectivity: `curl -k https://<remote-api-endpoint>:9443`
- Verify RERC secret has correct credentials
- Check firewall rules for ports 8443, 9443
- Verify ingress/route configuration

---

### Active-Active Database Not Syncing

**Symptoms:**
- REAADB created but data not replicating

**Check:**
```bash
kubectl describe reaadb <reaadb-name> -n <namespace>
# Check sync status in UI
```

**Common Causes:**
- RERC not connected
- Network issues between clusters
- Incompatible database configurations

**Solutions:**
- Verify all RERC are connected
- Check network connectivity between clusters
- Ensure database configurations match (modules, eviction policy, etc.)

---

## Performance Issues

### High Latency

**Check:**
- Resource utilization: `kubectl top pods -n <namespace>`
- Network latency between pods
- Storage performance

**Solutions:**
- Scale up resources (CPU/memory)
- Use faster storage class (SSD)
- Check for noisy neighbors on nodes

---

### Out of Memory

**Check:**
```bash
kubectl describe pod <rec-pod-name> -n <namespace>
kubectl logs <rec-pod-name> -n <namespace>
```

**Solutions:**
- Increase memory limits in REC spec
- Enable eviction policies on databases
- Scale cluster (add nodes)

---

## Platform-Specific Issues

### OpenShift: SCC Issues

**Symptoms:**
- Pods fail with security context errors

**Solution:**
```bash
oc apply -f openshift/scc.yaml
oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:<namespace>:redis-enterprise-operator
oc adm policy add-scc-to-user redis-enterprise-scc-v2 \
  system:serviceaccount:<namespace>:rec
```

---

### EKS: LoadBalancer Not Getting External IP

**Check:**
```bash
kubectl describe svc <service-name> -n <namespace>
```

**Solutions:**
- Verify AWS Load Balancer Controller is installed
- Check service annotations for AWS LB
- Verify subnet tags for EKS

---

## Useful Commands

```bash
# Get all Redis resources
kubectl get rec,redb,reaadb,rerc -n <namespace>

# Check operator logs
kubectl logs -n <operator-namespace> -l name=redis-enterprise-operator --tail=100

# Get events sorted by time
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Describe all pods
kubectl describe pods -n <namespace>

# Check resource usage
kubectl top pods -n <namespace>
kubectl top nodes
```

