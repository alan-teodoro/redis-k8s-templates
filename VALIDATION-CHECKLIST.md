# Installation Validation Checklist

Use this checklist to validate a fresh installation from scratch.

---

## Prerequisites ✅

- [ ] Kubernetes cluster running (EKS 1.23+)
- [ ] `kubectl` configured and working
- [ ] `helm` v3.x installed
- [ ] Cluster admin permissions verified

```bash
kubectl version --short
helm version --short
kubectl auth can-i '*' '*' --all-namespaces
```

---

## 1. Storage Configuration ✅

**Follow:** [platforms/eks/storage/README.md](platforms/eks/storage/README.md)

- [ ] gp3 StorageClass applied
- [ ] gp3 set as default
- [ ] Verified with `kubectl get storageclass`

**Expected:**
```
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   1m
```

---

## 2. Redis Enterprise Operator ✅

**Follow:** [operator/README.md](operator/README.md)

- [ ] Namespace `redis-enterprise` created
- [ ] Helm repo added (`helm.redis.io`)
- [ ] Operator version 8.0.6-8 installed
- [ ] RBAC for rack awareness applied
- [ ] Operator pod running

**Verification:**
```bash
kubectl get pods -n redis-enterprise
# Expected: redis-operator-redis-enterprise-operator-xxxxx   1/1     Running

kubectl get crd | grep redis
# Expected: Multiple CRDs (redisenterpriseclusters, redisenterprisedatabases, etc.)
```

---

## 3. Redis Enterprise Cluster ✅

**Follow:** [deployments/single-region/README.md](deployments/single-region/README.md)

- [ ] REC deployed (`02-rec.yaml`)
- [ ] Waited for ready condition (5-10 min)
- [ ] 3 REC pods running
- [ ] Admin password retrieved

**Verification:**
```bash
kubectl get rec -n redis-enterprise
# Expected: rec   Running   3/3

kubectl get pods -n redis-enterprise | grep rec-
# Expected: rec-0, rec-1, rec-2 all Running

kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d
# Expected: Password string
```

---

## 4. Test Database ✅

**Follow:** [deployments/single-region/README.md](deployments/single-region/README.md)

- [ ] REDB deployed (`03-redb.yaml`)
- [ ] Database ready
- [ ] TLS enabled (`tlsMode: enabled`)
- [ ] Database password retrieved
- [ ] Connection tested

**Verification:**
```bash
kubectl get redb test-db -n redis-enterprise
# Expected: test-db   active

kubectl get redb test-db -n redis-enterprise -o jsonpath='{.spec.tlsMode}'
# Expected: enabled

DB_PORT=$(kubectl get redb test-db -n redis-enterprise -o jsonpath='{.status.databasePort}')
DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

kubectl run -it --rm redis-test --image=redis:latest --restart=Never -- \
  redis-cli -h test-db.redis-enterprise.svc.cluster.local -p $DB_PORT --tls --insecure -a $DB_PASSWORD PING
# Expected: PONG
```

---

## 5. Monitoring (Optional) ✅

**Follow:** [monitoring/prometheus/README.md](monitoring/prometheus/README.md)

- [ ] kube-prometheus-stack installed
- [ ] ServiceMonitor applied
- [ ] PrometheusRules applied
- [ ] Grafana accessible
- [ ] Metrics visible in Prometheus

**Verification:**
```bash
kubectl get pods -n monitoring
# Expected: prometheus, grafana, alertmanager pods running

kubectl get servicemonitor redis-enterprise-cluster -n redis-enterprise
# Expected: ServiceMonitor exists

kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000 (admin / prom-operator)
```

---

## 6. Admission Controller (Optional) ✅

**Follow:** [operator/configuration/admission-controller/README.md](operator/configuration/admission-controller/README.md)

- [ ] Webhook applied
- [ ] ValidatingWebhookConfiguration exists

**Verification:**
```bash
kubectl get validatingwebhookconfiguration redb-admission
# Expected: ValidatingWebhookConfiguration exists
```

---

## 7. Gateway API - REC UI Access (Optional) ✅

**Follow:** [networking/gateway-api/nginx-gateway-fabric/README.md](networking/gateway-api/nginx-gateway-fabric/README.md)

- [ ] Gateway API CRDs installed (experimental)
- [ ] NGINX Gateway Fabric installed with experimental features
- [ ] TLS certificate created
- [ ] Gateway created and programmed
- [ ] Backend CA extracted
- [ ] BackendTLSPolicy applied
- [ ] HTTPRoute applied
- [ ] REC UI accessible via browser

**Verification:**
```bash
kubectl get gatewayclass
# Expected: nginx

kubectl get gateway redis-gateway -n nginx-gateway
# Expected: Programmed=True

GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)

curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
# Expected: HTML response with "Redis Enterprise"

# Browser test
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts
open https://ui.redis.example.com
# Expected: REC UI login page
```

---

## 8. Gateway API - Database Access (Optional) ✅

**Follow:** [networking/gateway-api/nginx-gateway-fabric/README.md](networking/gateway-api/nginx-gateway-fabric/README.md)

- [ ] TLSRoute applied
- [ ] TLSRoute accepted and refs resolved
- [ ] Database accessible via Gateway

**Verification:**
```bash
kubectl get tlsroute redis-db-tls-route -n redis-enterprise
# Expected: Accepted=True, ResolvedRefs=True

echo "$GATEWAY_IP db.redis.example.com" | sudo tee -a /etc/hosts

DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD PING
# Expected: PONG

redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD SET test "hello"
# Expected: OK

redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD GET test
# Expected: "hello"
```

---

## Summary

Total installation time: ~60-90 minutes (including optional components)

**Core components (required):**
1. Storage: 5 min
2. Operator: 10 min
3. Cluster & Database: 20 min

**Optional components:**
4. Monitoring: 15 min
5. Admission Controller: 5 min
6. Gateway API (UI + Database): 20 min

---

## Cleanup

To remove everything:

```bash
# Delete Gateway API resources
kubectl delete gateway redis-gateway -n nginx-gateway
kubectl delete namespace nginx-gateway

# Delete Redis Enterprise
kubectl delete redb test-db -n redis-enterprise
kubectl delete rec rec -n redis-enterprise

# Delete operator
helm uninstall redis-operator -n redis-enterprise

# Delete monitoring
helm uninstall kube-prometheus-stack -n monitoring

# Delete namespaces
kubectl delete namespace redis-enterprise
kubectl delete namespace monitoring
```

