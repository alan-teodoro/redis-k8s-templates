# Redis K8s Templates - EKS Validation Plan

**Purpose**: Validate core templates on AWS EKS by following README instructions exactly as a consultant would.

**Scope**: Phases 1, 2, 3, 5, 6, 7 (excluding Phase 4: Backup/Restore and Phase 8: Advanced)

**Estimated Time**: 3-4 hours

---

## 📋 Prerequisites

### EKS Cluster Access

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Verify access
kubectl cluster-info
kubectl get nodes

# Verify permissions
kubectl auth can-i create namespace
kubectl auth can-i create customresourcedefinition
kubectl auth can-i create clusterrole
```

### Required Tools

- `kubectl` CLI
- `helm` (v3+)
- `curl`
- `redis-cli` (for connection testing)

### EKS Cluster Requirements

- **Kubernetes Version**: 1.24+
- **Worker Nodes**: 3+ nodes
- **Instance Type**: t3.large or larger
- **Storage**: EBS CSI driver with gp3 StorageClass
- **Network**: VPC with public/private subnets

---

## 🎯 Validation Phases

### Phase 1: Foundation Setup ⏱️ ~15 min

**Objective**: Establish base Redis Enterprise environment

#### 1.1 Single-Region Deployment

**Path**: `deployments/single-region/`

```bash
# Follow: deployments/single-region/README.md

# 1. Create namespace
kubectl apply -f deployments/single-region/01-namespace.yaml
kubectl get namespace redis-enterprise

# 2. Install Redis Enterprise Operator
kubectl apply -f deployments/single-region/02-operator.yaml
kubectl rollout status deployment/redis-enterprise-operator -n redis-enterprise --timeout=300s
kubectl get pods -n redis-enterprise

# 3. Create Redis Enterprise Cluster (REC)
kubectl apply -f deployments/single-region/03-rec.yaml
kubectl wait --for=condition=Ready rec/rec -n redis-enterprise --timeout=600s
kubectl get rec -n redis-enterprise

# 4. Create first database (REDB)
kubectl apply -f deployments/single-region/04-redb-basic.yaml
kubectl wait --for=condition=Ready redb/redis-db -n redis-enterprise --timeout=300s
kubectl get redb -n redis-enterprise

# 5. Test connectivity
kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 PING

# Expected: PONG

# 6. Test data operations
kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 \
  SET testkey "Hello Redis"

kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 \
  GET testkey

# Expected: "Hello Redis"
```

**Success Criteria**:
- ✅ Namespace created
- ✅ Operator pod running (1/1)
- ✅ REC status: Ready (3 pods running)
- ✅ REDB status: Ready
- ✅ redis-cli PING returns PONG
- ✅ SET/GET operations work
- ✅ README instructions accurate

**Cleanup**: ✅ Keep for next tests (delete REDB only if needed)

```bash
# Optional: Delete test database
kubectl delete -f deployments/single-region/04-redb-basic.yaml
```

---

### Phase 2: Deployment Patterns ⏱️ ~30 min

#### 2.1 Multi-Namespace REDB

**Path**: `deployments/multi-namespace/`

```bash
# Follow: deployments/multi-namespace/README.md

# 1. Create app namespace
kubectl apply -f deployments/multi-namespace/01-app-namespace.yaml
kubectl get namespace app-namespace

# 2. Create RBAC for remote namespace
kubectl apply -f deployments/multi-namespace/02-rbac.yaml
kubectl get clusterrole redis-enterprise-remote-namespace
kubectl get clusterrolebinding redis-enterprise-remote-namespace

# 3. Create admission controller
kubectl apply -f deployments/multi-namespace/03-admission-controller.yaml
kubectl get validatingwebhookconfiguration redb-admission

# 4. Create REDB in app namespace
kubectl apply -f deployments/multi-namespace/04-redb-remote.yaml
kubectl wait --for=condition=Ready redb/app-db -n app-namespace --timeout=300s
kubectl get redb -n app-namespace

# 5. Verify service in app namespace
kubectl get svc -n app-namespace

# 6. Test connectivity from app namespace
kubectl run redis-test --rm -it --image=redis:latest -n app-namespace -- \
  redis-cli -h app-db.app-namespace.svc.cluster.local -p 12000 PING

# Expected: PONG

# 7. Verify admission controller
kubectl get redb app-db -n app-namespace -o yaml | grep -A 5 "redisEnterpriseCluster"
```

**Success Criteria**:
- ✅ App namespace created
- ✅ RBAC configured correctly
- ✅ Admission controller running
- ✅ REDB created in app-namespace
- ✅ Service accessible from app-namespace
- ✅ Admission controller validates requests

**Cleanup**:
```bash
kubectl delete -f deployments/multi-namespace/04-redb-remote.yaml
kubectl delete -f deployments/multi-namespace/03-admission-controller.yaml
kubectl delete -f deployments/multi-namespace/02-rbac.yaml
kubectl delete -f deployments/multi-namespace/01-app-namespace.yaml
```

---

#### 2.2 Redis on Flash

**Path**: `deployments/redis-on-flash/`

```bash
# Follow: deployments/redis-on-flash/README.md

# 1. Verify StorageClass exists (EBS gp3)
kubectl get storageclass
# Expected: gp2 or gp3 StorageClass

# 2. Create Redis on Flash database
kubectl apply -f deployments/redis-on-flash/01-redb-rof.yaml
kubectl wait --for=condition=Ready redb/redis-rof -n redis-enterprise --timeout=300s
kubectl get redb redis-rof -n redis-enterprise

# 3. Verify RoF configuration
kubectl get redb redis-rof -n redis-enterprise -o yaml | grep -A 10 "redisOnFlash"

# 4. Verify PVC created for flash storage
kubectl get pvc -n redis-enterprise | grep redis-rof

# 5. Test connectivity
kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-rof.redis-enterprise.svc.cluster.local -p 12000 PING

# 6. Test with data
kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-rof.redis-enterprise.svc.cluster.local -p 12000 \
  SET rof-key "Flash storage test"

kubectl run redis-test --rm -it --image=redis:latest -n redis-enterprise -- \
  redis-cli -h redis-rof.redis-enterprise.svc.cluster.local -p 12000 \
  GET rof-key
```

**Success Criteria**:
- ✅ REDB with RoF enabled
- ✅ PVC created for flash storage
- ✅ Database accessible
- ✅ Data operations work

**Cleanup**:
```bash
kubectl delete -f deployments/redis-on-flash/01-redb-rof.yaml
# Wait for PVC to be released
kubectl get pvc -n redis-enterprise
# Delete PVC if not auto-deleted
kubectl delete pvc <pvc-name> -n redis-enterprise
```

---

#### 2.3 RedisInsight

**Path**: `deployments/redisinsight/`

```bash
# Follow: deployments/redisinsight/README.md

# Test 1: Ephemeral deployment (dev/test)
kubectl apply -f deployments/redisinsight/01-deployment-ephemeral.yaml
kubectl apply -f deployments/redisinsight/04-service-clusterip.yaml
kubectl wait --for=condition=Ready pod -l app=redisinsight -n redis-enterprise --timeout=180s
kubectl get pods -n redis-enterprise -l app=redisinsight

# Test port-forward access
kubectl port-forward svc/redisinsight-svc 5540:5540 -n redis-enterprise &
# Open browser: http://localhost:5540
# Verify UI loads and can connect to databases

# Stop port-forward
pkill -f "port-forward svc/redisinsight-svc"

# Cleanup ephemeral
kubectl delete -f deployments/redisinsight/04-service-clusterip.yaml
kubectl delete -f deployments/redisinsight/01-deployment-ephemeral.yaml

# Test 2: Persistent deployment (production)
kubectl apply -f deployments/redisinsight/02-deployment-persistent.yaml
kubectl apply -f deployments/redisinsight/04-service-clusterip.yaml
kubectl wait --for=condition=Ready pod -l app=redisinsight -n redis-enterprise --timeout=180s

# Verify PVC created
kubectl get pvc -n redis-enterprise | grep redisinsight

# Test port-forward again
kubectl port-forward svc/redisinsight-svc 5540:5540 -n redis-enterprise &
# Verify UI loads

# Stop port-forward
pkill -f "port-forward svc/redisinsight-svc"
```

**Success Criteria**:
- ✅ Ephemeral deployment works
- ✅ Persistent deployment works
- ✅ PVC created for persistent storage
- ✅ RedisInsight UI accessible via port-forward
- ✅ Can connect to Redis databases

**Cleanup**:
```bash
kubectl delete -f deployments/redisinsight/04-service-clusterip.yaml
kubectl delete -f deployments/redisinsight/02-deployment-persistent.yaml
kubectl delete pvc redisinsight-pvc -n redis-enterprise
```

---

### Phase 3: Security ⏱️ ~40 min

#### 3.1 Network Policies

**Path**: `security/network-policies/`

```bash
# Follow: security/network-policies/README.md

# 1. Create test database first
kubectl apply -f deployments/single-region/04-redb-basic.yaml
kubectl wait --for=condition=Ready redb/redis-db -n redis-enterprise --timeout=300s

# 2. Test connectivity BEFORE network policies (should work)
kubectl run redis-test-before --rm -it --image=redis:latest -n default -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 PING
# Expected: PONG

# 3. Apply network policies
kubectl apply -f security/network-policies/01-deny-all.yaml
kubectl apply -f security/network-policies/02-allow-redis-enterprise.yaml
kubectl apply -f security/network-policies/03-allow-app-to-redis.yaml

# 4. Verify network policies created
kubectl get networkpolicy -n redis-enterprise

# 5. Test connectivity with allowed label (should work)
kubectl run redis-test-allowed --rm -it --image=redis:latest -n redis-enterprise \
  --labels="app=allowed-app" -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 PING
# Expected: PONG

# 6. Test connectivity without label (should timeout/fail)
kubectl run redis-test-blocked --rm -it --image=redis:latest -n default -- \
  redis-cli -h redis-db.redis-enterprise.svc.cluster.local -p 12000 --connect-timeout 5 PING
# Expected: timeout or connection refused
```

**Success Criteria**:
- ✅ Network policies created
- ✅ Allowed pods can connect
- ✅ Blocked pods cannot connect
- ✅ Redis Enterprise internal communication works

**Cleanup**:
```bash
kubectl delete -f security/network-policies/03-allow-app-to-redis.yaml
kubectl delete -f security/network-policies/02-allow-redis-enterprise.yaml
kubectl delete -f security/network-policies/01-deny-all.yaml
kubectl delete -f deployments/single-region/04-redb-basic.yaml
```

---

#### 3.2 RBAC

**Path**: `security/rbac/`

```bash
# Follow: security/rbac/README.md

# 1. Create read-only role
kubectl apply -f security/rbac/01-role-readonly.yaml
kubectl get role redis-readonly -n redis-enterprise

# 2. Create read-write role
kubectl apply -f security/rbac/02-role-readwrite.yaml
kubectl get role redis-readwrite -n redis-enterprise

# 3. Create admin role
kubectl apply -f security/rbac/03-role-admin.yaml
kubectl get role redis-admin -n redis-enterprise

# 4. Create test service account
kubectl create serviceaccount redis-readonly-sa -n redis-enterprise

# 5. Bind read-only role
kubectl create rolebinding redis-readonly-binding \
  --role=redis-readonly \
  --serviceaccount=redis-enterprise:redis-readonly-sa \
  -n redis-enterprise

# 6. Test permissions
kubectl auth can-i get redb --as=system:serviceaccount:redis-enterprise:redis-readonly-sa -n redis-enterprise
# Expected: yes

kubectl auth can-i create redb --as=system:serviceaccount:redis-enterprise:redis-readonly-sa -n redis-enterprise
# Expected: no

kubectl auth can-i delete redb --as=system:serviceaccount:redis-enterprise:redis-readonly-sa -n redis-enterprise
# Expected: no
```

**Success Criteria**:
- ✅ Roles created correctly
- ✅ Read-only role can only view resources
- ✅ Read-write role can create/update but not delete
- ✅ Admin role has full permissions

**Cleanup**:
```bash
kubectl delete rolebinding redis-readonly-binding -n redis-enterprise
kubectl delete serviceaccount redis-readonly-sa -n redis-enterprise
kubectl delete -f security/rbac/03-role-admin.yaml
kubectl delete -f security/rbac/02-role-readwrite.yaml
kubectl delete -f security/rbac/01-role-readonly.yaml
```

---

#### 3.3 Pod Security Standards

**Path**: `security/pod-security/`

```bash
# Follow: security/pod-security/README.md

# 1. Apply pod security labels to namespace
kubectl label namespace redis-enterprise \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

# 2. Verify labels
kubectl get namespace redis-enterprise --show-labels

# 3. Test that existing pods comply
kubectl get pods -n redis-enterprise

# 4. Try to create non-compliant pod (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: non-compliant-pod
  namespace: redis-enterprise
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true
EOF
# Expected: Error/Warning about pod security

# 5. Create compliant pod (should work)
kubectl apply -f security/pod-security/01-compliant-pod.yaml
kubectl wait --for=condition=Ready pod/compliant-pod -n redis-enterprise --timeout=60s
```

**Success Criteria**:
- ✅ Pod security labels applied
- ✅ Non-compliant pods rejected
- ✅ Compliant pods accepted
- ✅ Existing Redis Enterprise pods still running

**Cleanup**:
```bash
kubectl delete -f security/pod-security/01-compliant-pod.yaml
kubectl delete pod non-compliant-pod -n redis-enterprise --ignore-not-found
# Remove pod security labels
kubectl label namespace redis-enterprise \
  pod-security.kubernetes.io/enforce- \
  pod-security.kubernetes.io/audit- \
  pod-security.kubernetes.io/warn-
```

---

### Phase 5: Observability ⏱️ ~35 min

#### 5.1 Prometheus + ServiceMonitor

**Path**: `observability/prometheus/`

```bash
# Follow: observability/prometheus/README.md

# 1. Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# 2. Wait for Prometheus to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

# 3. Apply ServiceMonitor for Redis Enterprise
kubectl apply -f observability/prometheus/01-servicemonitor.yaml
kubectl get servicemonitor -n redis-enterprise

# 4. Verify metrics collection
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
# Open browser: http://localhost:9090
# Query: redis_up
# Expected: See Redis Enterprise metrics

# 5. Check targets
# In Prometheus UI: Status > Targets
# Look for redis-enterprise/redis-enterprise-servicemonitor

# Stop port-forward
pkill -f "port-forward.*prometheus"
```

**Success Criteria**:
- ✅ Prometheus Operator installed
- ✅ ServiceMonitor created
- ✅ Prometheus scraping Redis metrics
- ✅ Metrics visible in Prometheus UI
- ✅ Targets showing as UP

**Cleanup**:
```bash
kubectl delete -f observability/prometheus/01-servicemonitor.yaml
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

---

#### 5.2 Grafana Dashboards

**Path**: `observability/grafana/`

```bash
# Follow: observability/grafana/README.md

# 1. Install Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -n monitoring --create-namespace \
  --set persistence.enabled=false

# 2. Wait for Grafana to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s

# 3. Get Grafana admin password
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
echo

# 4. Apply dashboard ConfigMap
kubectl apply -f observability/grafana/01-dashboard-configmap.yaml

# 5. Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80 &
# Open browser: http://localhost:3000
# Login: admin / <password from step 3>

# 6. Verify dashboards loaded
# In Grafana UI: Dashboards > Browse
# Look for Redis Enterprise dashboards

# Stop port-forward
pkill -f "port-forward.*grafana"
```

**Success Criteria**:
- ✅ Grafana installed
- ✅ Dashboard ConfigMap created
- ✅ Dashboards visible in Grafana UI
- ✅ Metrics displayed correctly

**Cleanup**:
```bash
kubectl delete -f observability/grafana/01-dashboard-configmap.yaml
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring
```

---

#### 5.3 Loki + Promtail

**Path**: `observability/logging/loki/`

```bash
# Follow: observability/logging/loki/README.md

# 1. Install Loki stack
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack -n logging --create-namespace \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=false

# 2. Wait for Loki to be ready
kubectl wait --for=condition=Ready pod -l app=loki -n logging --timeout=180s
kubectl wait --for=condition=Ready pod -l app=promtail -n logging --timeout=180s

# 3. Verify Promtail is collecting logs
kubectl logs -n logging -l app=promtail --tail=50

# 4. Install Grafana (if not already installed)
helm install grafana grafana/grafana -n logging \
  --set persistence.enabled=false

# 5. Get Grafana password
kubectl get secret grafana -n logging -o jsonpath="{.data.admin-password}" | base64 --decode
echo

# 6. Access Grafana
kubectl port-forward -n logging svc/grafana 3000:80 &

# 7. Add Loki datasource in Grafana
# URL: http://loki:3100

# 8. Query logs
# Query: {namespace="redis-enterprise"}
# Expected: See Redis Enterprise logs

# Stop port-forward
pkill -f "port-forward.*grafana"
```

**Success Criteria**:
- ✅ Loki installed and running
- ✅ Promtail collecting logs
- ✅ Logs queryable in Grafana
- ✅ Can filter by namespace

**Cleanup**:
```bash
helm uninstall grafana -n logging
helm uninstall loki -n logging
kubectl delete namespace logging
```

---

### Phase 6: Operations ⏱️ ~25 min

#### 6.1 Performance Testing

**Path**: `operations/performance-testing/`

```bash
# Follow: operations/performance-testing/README.md

# 1. Create test database
kubectl apply -f deployments/single-region/04-redb-basic.yaml
kubectl wait --for=condition=Ready redb/redis-db -n redis-enterprise --timeout=300s

# 2. Deploy memtier_benchmark pod
kubectl apply -f operations/performance-testing/01-memtier-benchmark-pod.yaml
kubectl wait --for=condition=Ready pod/memtier-benchmark -n redis-enterprise --timeout=120s

# 3. Run interactive test
kubectl exec -it memtier-benchmark -n redis-enterprise -- \
  memtier_benchmark \
  -s redis-db.redis-enterprise.svc.cluster.local \
  -p 12000 \
  --protocol=redis \
  --clients=50 \
  --threads=4 \
  --requests=10000 \
  --data-size=1024 \
  --ratio=1:1 \
  --print-percentiles=50,95,99,99.9

# 4. Run automated job
kubectl apply -f operations/performance-testing/02-memtier-benchmark-job.yaml
kubectl wait --for=condition=Complete job/memtier-benchmark-job -n redis-enterprise --timeout=600s

# 5. View job results
kubectl logs job/memtier-benchmark-job -n redis-enterprise

# 6. Test redis-benchmark (built-in tool)
kubectl apply -f operations/performance-testing/03-redis-benchmark-pod.yaml
kubectl wait --for=condition=Ready pod/redis-benchmark -n redis-enterprise --timeout=60s

kubectl exec -it redis-benchmark -n redis-enterprise -- \
  redis-benchmark -h redis-db.redis-enterprise.svc.cluster.local -p 12000 \
  -c 50 -n 100000 -d 1024 -t get,set
```

**Success Criteria**:
- ✅ memtier_benchmark pod runs successfully
- ✅ Interactive test completes
- ✅ Automated job completes
- ✅ Performance metrics collected
- ✅ redis-benchmark works

**Cleanup**:
```bash
kubectl delete -f operations/performance-testing/03-redis-benchmark-pod.yaml
kubectl delete -f operations/performance-testing/02-memtier-benchmark-job.yaml
kubectl delete -f operations/performance-testing/01-memtier-benchmark-pod.yaml
kubectl delete -f deployments/single-region/04-redb-basic.yaml
```

---

#### 6.2 Log Collector

**Path**: `operations/troubleshooting/log-collector/`

```bash
# Follow: operations/troubleshooting/log-collector/README.md

# 1. Download log collector script
curl -LO https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/log_collector/log_collector.py

# 2. Install dependencies
pip3 install pyyaml

# 3. Run log collector
python3 log_collector.py -n redis-enterprise -o /tmp/redis-logs

# 4. Verify output
ls -lh /tmp/redis-logs/redis_enterprise_k8s_debug_info_*.tar.gz

# 5. Extract and verify contents
cd /tmp/redis-logs
tar -xzf redis_enterprise_k8s_debug_info_*.tar.gz
ls -la redis_enterprise_k8s_debug_info_*/

# 6. Verify collected data
ls redis_enterprise_k8s_debug_info_*/pods/
ls redis_enterprise_k8s_debug_info_*/custom_resources/
cat redis_enterprise_k8s_debug_info_*/events.yaml
```

**Success Criteria**:
- ✅ Log collector runs successfully
- ✅ tar.gz file created
- ✅ Contains pod logs
- ✅ Contains custom resources (REC, REDB)
- ✅ Contains events
- ✅ Contains cluster info

**Cleanup**:
```bash
rm -rf /tmp/redis-logs
rm log_collector.py
```

---

### Phase 7: Networking ⏱️ ~20 min

#### 7.1 NGINX Ingress

**Path**: `networking/ingress/nginx/`

```bash
# Follow: networking/ingress/nginx/README.md

# 1. Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer

# 2. Wait for LoadBalancer IP
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
kubectl get svc -n ingress-nginx ingress-nginx-controller

# 3. Create database
kubectl apply -f deployments/single-region/04-redb-basic.yaml
kubectl wait --for=condition=Ready redb/redis-db -n redis-enterprise --timeout=300s

# 4. Apply Ingress
kubectl apply -f networking/ingress/nginx/01-ingress-redis.yaml
kubectl get ingress -n redis-enterprise

# 5. Get Ingress external IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Ingress URL: $INGRESS_IP"

# 6. Test connection through Ingress (if external IP available)
# redis-cli -h $INGRESS_IP -p 80 PING

# Note: May need to configure DNS or use /etc/hosts for hostname-based routing
```

**Success Criteria**:
- ✅ NGINX Ingress Controller installed
- ✅ LoadBalancer service created
- ✅ External IP/hostname assigned
- ✅ Ingress resource created
- ✅ Connection works through Ingress (if accessible)

**Cleanup** (IMPORTANT - Delete LoadBalancer to avoid costs):
```bash
kubectl delete -f networking/ingress/nginx/01-ingress-redis.yaml
kubectl delete -f deployments/single-region/04-redb-basic.yaml
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
# Verify LoadBalancer deleted in AWS console
```

---

#### 7.2 Gateway API (NGINX Gateway Fabric)

**Path**: `networking/gateway-api/`

```bash
# Follow: networking/gateway-api/README.md

# 1. Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# 2. Install NGINX Gateway Fabric
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm install nginx-gateway nginx-stable/nginx-gateway \
  -n nginx-gateway --create-namespace

# 3. Wait for gateway to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=nginx-gateway -n nginx-gateway --timeout=300s

# 4. Create Gateway
kubectl apply -f networking/gateway-api/01-gateway.yaml
kubectl get gateway -n redis-enterprise

# 5. Create database
kubectl apply -f deployments/single-region/04-redb-basic.yaml
kubectl wait --for=condition=Ready redb/redis-db -n redis-enterprise --timeout=300s

# 6. Create HTTPRoute
kubectl apply -f networking/gateway-api/02-httproute.yaml
kubectl get httproute -n redis-enterprise

# 7. Verify Gateway status
kubectl describe gateway redis-gateway -n redis-enterprise
```

**Success Criteria**:
- ✅ Gateway API CRDs installed
- ✅ NGINX Gateway Fabric running
- ✅ Gateway created
- ✅ HTTPRoute created
- ✅ Gateway status shows Ready

**Cleanup**:
```bash
kubectl delete -f networking/gateway-api/02-httproute.yaml
kubectl delete -f networking/gateway-api/01-gateway.yaml
kubectl delete -f deployments/single-region/04-redb-basic.yaml
helm uninstall nginx-gateway -n nginx-gateway
kubectl delete namespace nginx-gateway
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

---

## 🧹 Final Cleanup

After completing all validation phases:

```bash
# 1. Delete all test databases
kubectl delete redb --all -n redis-enterprise

# 2. Delete Redis Enterprise Cluster
kubectl delete rec --all -n redis-enterprise

# 3. Delete Operator
kubectl delete -f deployments/single-region/02-operator.yaml

# 4. Delete namespace
kubectl delete namespace redis-enterprise

# 5. Verify all PVCs deleted
kubectl get pvc -n redis-enterprise

# 6. Delete any remaining PVCs
kubectl delete pvc --all -n redis-enterprise

# 7. Verify cleanup
kubectl get all -n redis-enterprise
kubectl get pvc -n redis-enterprise

# 8. Verify no LoadBalancers remain (IMPORTANT for cost)
kubectl get svc --all-namespaces | grep LoadBalancer
```

---

## ✅ Success Criteria Summary

### Per Template
- ✅ README instructions clear and accurate
- ✅ All kubectl commands execute successfully
- ✅ Resources reach Ready/Running state
- ✅ Functionality works as documented
- ✅ Cleanup completes without errors

### Overall Validation
- ✅ All 7 phases completed
- ✅ No errors in deployments
- ✅ All tests pass
- ✅ Documentation accurate
- ✅ No Portuguese text found
- ✅ All referenced files exist

---

## 📊 Validation Report Template

After each phase, document results:

```markdown
# Phase X Validation Report

**Date**: YYYY-MM-DD
**Phase**: [Phase Name]
**Status**: ✅ PASS / ⚠️ PASS WITH ISSUES / ❌ FAIL

## Tests Executed

| Test | Status | Time | Notes |
|------|--------|------|-------|
| Test 1 | ✅ PASS | 5 min | - |
| Test 2 | ❌ FAIL | 2 min | Error: PVC not bound |

## Issues Found

1. **Issue**: [Description]
   - **Severity**: HIGH/MEDIUM/LOW
   - **Fix**: [Proposed fix]

## Recommendations

1. [Recommendation 1]
2. [Recommendation 2]

## Overall
- **Total Time**: X minutes
- **Tests Passed**: X/Y
- **Cleanup**: ✅ COMPLETE
```

---

## 📝 Execution Checklist

- [ ] Phase 1: Foundation Setup (~15 min)
  - [ ] 1.1 Single-Region Deployment
- [ ] Phase 2: Deployment Patterns (~30 min)
  - [ ] 2.1 Multi-Namespace REDB
  - [ ] 2.2 Redis on Flash
  - [ ] 2.3 RedisInsight
- [ ] Phase 3: Security (~40 min)
  - [ ] 3.1 Network Policies
  - [ ] 3.2 RBAC
  - [ ] 3.3 Pod Security Standards
- [ ] Phase 5: Observability (~35 min)
  - [ ] 5.1 Prometheus + ServiceMonitor
  - [ ] 5.2 Grafana Dashboards
  - [ ] 5.3 Loki + Promtail
- [ ] Phase 6: Operations (~25 min)
  - [ ] 6.1 Performance Testing
  - [ ] 6.2 Log Collector
- [ ] Phase 7: Networking (~20 min)
  - [ ] 7.1 NGINX Ingress
  - [ ] 7.2 Gateway API
- [ ] Final Cleanup

**Total Estimated Time**: 3-4 hours

---

## 🚀 Ready to Start

When you provide EKS cluster access, I will:

1. ✅ Execute each phase in order
2. ✅ Follow README instructions exactly
3. ✅ Document results for each test
4. ✅ Clean up resources after each phase
5. ✅ Report any issues found
6. ✅ Suggest fixes for problems
7. ✅ Verify all documentation is accurate

**Provide cluster access with**:
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

Let's validate! 🎯

