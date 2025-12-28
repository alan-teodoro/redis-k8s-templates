# Multi-Namespace REDB - Troubleshooting

Guia completo de troubleshooting para deployments multi-namespace.

---

## 🔍 Problemas Comuns

### 1. REDB não é criado no consumer namespace

**Sintoma:**
```bash
kubectl get redb -n app-production
# No resources found
```

**Causas possíveis:**

#### A) RBAC não configurado corretamente

**Verificar:**
```bash
# Verificar ClusterRole
kubectl get clusterrole redis-enterprise-operator-consumer-ns

# Verificar ClusterRoleBinding
kubectl get clusterrolebinding redis-enterprise-operator-consumer-ns

# Verificar Role no consumer namespace
kubectl get role redb-role -n app-production

# Verificar RoleBinding no consumer namespace
kubectl get rolebinding redb-role -n app-production
```

**Solução:**
```bash
# Reaplicar RBAC
kubectl apply -f 01-operator-rbac.yaml
kubectl apply -f 03-consumer-rbac.yaml
```

#### B) ServiceAccount incorreto no RoleBinding

**Verificar:**
```bash
# Verificar nome do ServiceAccount do REC
kubectl get rec redis-enterprise -n redis-enterprise -o jsonpath='{.spec.serviceAccountName}'

# Verificar RoleBinding
kubectl get rolebinding redb-role -n app-production -o yaml
```

**Solução:**
Se o ServiceAccount do REC for diferente de `redis-enterprise`, edite o RoleBinding:
```bash
kubectl edit rolebinding redb-role -n app-production
# Altere o nome do ServiceAccount para o correto
```

#### C) Namespace não tem label correto

**Verificar:**
```bash
kubectl get namespace app-production --show-labels
```

**Solução:**
```bash
kubectl label namespace app-production redis-enterprise-consumer=true
```

---

### 2. REDB fica em estado "Pending"

**Sintoma:**
```bash
kubectl get redb -n app-production
# NAME         STATUS    AGE
# prod-db-1    Pending   5m
```

**Verificar logs do operator:**
```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

**Causas possíveis:**

#### A) REC não tem recursos suficientes

**Verificar:**
```bash
kubectl describe rec redis-enterprise -n redis-enterprise
```

**Solução:**
Reduzir `memorySize` do REDB ou escalar o REC.

#### B) Erro de conectividade entre namespaces

**Verificar:**
```bash
# Verificar se o operator consegue acessar o consumer namespace
kubectl auth can-i list redisenterprisedatabases \
  --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator \
  -n app-production
```

**Solução:**
Reaplicar RBAC conforme item 1.

---

### 3. Não consigo conectar ao database

**Sintoma:**
```bash
redis-cli -h prod-db-1.app-production.svc.cluster.local -p 12000
# Could not connect
```

**Verificar service:**
```bash
kubectl get svc -n app-production
kubectl describe svc prod-db-1 -n app-production
```

**Verificar endpoints:**
```bash
kubectl get endpoints prod-db-1 -n app-production
```

**Causas possíveis:**

#### A) Service não foi criado

**Solução:**
```bash
# Verificar logs do operator
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100

# Verificar permissões de services no consumer namespace
kubectl auth can-i create services \
  --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator \
  -n app-production
```

#### B) TLS habilitado mas cliente não usa TLS

**Solução:**
```bash
# Conectar com TLS
redis-cli -h prod-db-1.app-production.svc.cluster.local -p 12000 --tls \
  --cert /path/to/client.crt \
  --key /path/to/client.key \
  --cacert /path/to/ca.crt
```

---

### 4. Secret de credenciais não é criado

**Sintoma:**
```bash
kubectl get secret -n app-production | grep redb
# No resources found
```

**Verificar:**
```bash
# Verificar permissões de secrets
kubectl auth can-i create secrets \
  --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator \
  -n app-production

# Verificar logs do operator
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

**Solução:**
Reaplicar RBAC conforme item 1.

---

### 5. Operator não detecta consumer namespace

**Sintoma:**
Operator não cria recursos no consumer namespace.

**Verificar:**
```bash
# Verificar se operator tem permissão para listar namespaces
kubectl auth can-i list namespaces \
  --as=system:serviceaccount:redis-enterprise:redis-enterprise-operator

# Verificar logs do operator
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator --tail=100
```

**Solução:**
```bash
# Reaplicar ClusterRole e ClusterRoleBinding
kubectl apply -f 01-operator-rbac.yaml

# Reiniciar operator
kubectl rollout restart deployment redis-enterprise-operator -n redis-enterprise
```

---

## 🔧 Comandos Úteis

### Verificar status de todos os REDBs

```bash
kubectl get redb -A
```

### Verificar logs do operator

```bash
kubectl logs -n redis-enterprise deployment/redis-enterprise-operator -f
```

### Verificar eventos em um namespace

```bash
kubectl get events -n app-production --sort-by='.lastTimestamp'
```

### Verificar RBAC completo

```bash
# ClusterRole
kubectl get clusterrole redis-enterprise-operator-consumer-ns -o yaml

# ClusterRoleBinding
kubectl get clusterrolebinding redis-enterprise-operator-consumer-ns -o yaml

# Roles em todos os consumer namespaces
kubectl get role redb-role -n app-production -o yaml
kubectl get role redb-role -n app-staging -o yaml
kubectl get role redb-role -n app-development -o yaml

# RoleBindings em todos os consumer namespaces
kubectl get rolebinding redb-role -n app-production -o yaml
kubectl get rolebinding redb-role -n app-staging -o yaml
kubectl get rolebinding redb-role -n app-development -o yaml
```

### Testar conectividade

```bash
# Criar pod de teste no consumer namespace
kubectl run redis-test -n app-production --rm -it --image=redis:latest -- bash

# Dentro do pod:
redis-cli -h prod-db-1 -p 12000 ping
```

---

## 📚 Referências

- [Documentação Oficial - Multi-Namespace](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/multi-namespace/)
- [RBAC Troubleshooting](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

