# Multi-Namespace REDB Deployment

Deploy Redis Enterprise databases (REDB) across multiple Kubernetes namespaces for better resource isolation and organization.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Guia de Deployment](#guia-de-deployment)
- [Casos de Uso](#casos-de-uso)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

### O que é Multi-Namespace REDB?

**Multi-namespace deployment** permite que um único **Redis Enterprise Operator** gerencie clusters (REC) e databases (REDB) em **diferentes namespaces**, proporcionando:

✅ **Isolamento de Namespace**: Separar recursos Redis por time, ambiente ou aplicação  
✅ **Gerenciamento Centralizado**: Um único operator gerencia múltiplos namespaces  
✅ **Compartilhamento de Recursos**: Uso eficiente de recursos do cluster  
✅ **RBAC Flexível**: Permissões granulares por namespace  

### Benefícios

| Benefício | Descrição |
|-----------|-----------|
| **Isolamento** | Cada time/app tem seu próprio namespace com REDBs isolados |
| **Segurança** | RBAC por namespace, limitando acesso entre times |
| **Organização** | Separação clara entre ambientes (prod, staging, dev) |
| **Eficiência** | Um único REC pode servir múltiplos namespaces |
| **Escalabilidade** | Adicionar novos namespaces sem novos operators |

---

## 🏗️ Arquitetura

### Estrutura de Namespaces

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: redis-enterprise (Operator Namespace)    │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - Redis Enterprise Operator                         │   │
│  │  - RedisEnterpriseCluster (REC)                      │   │
│  │  - REC Pods (rec-redis-enterprise-0, 1, 2)           │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           │ Manages                           │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-production (Consumer Namespace)      │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - prod-db-1        │   │
│  │  - RedisEnterpriseDatabase (REDB) - prod-db-2        │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-staging (Consumer Namespace)         │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - staging-db-1     │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: app-development (Consumer Namespace)     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  - RedisEnterpriseDatabase (REDB) - dev-db-1         │   │
│  │  - Services (database endpoints)                     │   │
│  │  - Secrets (database credentials)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Componentes

1. **Operator Namespace** (`redis-enterprise`):
   - Redis Enterprise Operator
   - RedisEnterpriseCluster (REC)
   - REC Pods (cluster nodes)

2. **Consumer Namespaces** (`app-production`, `app-staging`, `app-development`):
   - RedisEnterpriseDatabase (REDB) resources
   - Services (database endpoints)
   - Secrets (credentials)

---

## ✅ Pré-requisitos

### 1. Cluster Kubernetes

```bash
kubectl version --short
# Client Version: v1.28+
# Server Version: v1.28+
```

### 2. Redis Enterprise Operator Instalado

O operator deve estar instalado no namespace `redis-enterprise`:

```bash
kubectl get deployment redis-enterprise-operator -n redis-enterprise
```

### 3. RedisEnterpriseCluster (REC) Criado

```bash
kubectl get rec -n redis-enterprise
# NAME                  AGE
# redis-enterprise      10m
```

### 4. Permissões RBAC

Você precisa de permissões para:
- Criar namespaces
- Criar ClusterRoles e ClusterRoleBindings
- Criar Roles e RoleBindings em múltiplos namespaces

---

## 📖 Guia de Deployment

### Passo 1: Configurar RBAC para Multi-Namespace

```bash
# Aplicar RBAC para operator gerenciar múltiplos namespaces
kubectl apply -f 01-operator-rbac.yaml
```

Este arquivo cria:
- **ClusterRole**: Permissões para operator listar namespaces
- **ClusterRoleBinding**: Vincula ClusterRole ao ServiceAccount do operator

### Passo 2: Criar Consumer Namespaces

```bash
# Criar namespaces para databases
kubectl apply -f 02-consumer-namespaces.yaml
```

Cria 3 namespaces:
- `app-production`
- `app-staging`
- `app-development`

### Passo 3: Configurar RBAC nos Consumer Namespaces

```bash
# Aplicar RBAC em cada consumer namespace
kubectl apply -f 03-consumer-rbac.yaml
```

Este arquivo cria em **cada consumer namespace**:
- **Role**: Permissões para gerenciar REDBs, secrets, services
- **RoleBinding**: Vincula Role aos ServiceAccounts (operator + REC)

### Passo 4: Criar REDBs nos Consumer Namespaces

```bash
# Criar databases em cada namespace
kubectl apply -f 04-redb-production.yaml
kubectl apply -f 05-redb-staging.yaml
kubectl apply -f 06-redb-development.yaml
```

### Passo 5: Verificar Deployment

```bash
# Verificar REDBs em todos os namespaces
kubectl get redb -A

# Verificar status detalhado
kubectl describe redb prod-db-1 -n app-production
kubectl describe redb staging-db-1 -n app-staging
kubectl describe redb dev-db-1 -n app-development
```

---

## 🎯 Casos de Uso

### 1. Isolamento por Time

```
Namespace: team-backend    → Backend databases
Namespace: team-frontend   → Frontend databases
Namespace: team-analytics  → Analytics databases
```

### 2. Isolamento por Ambiente

```
Namespace: production  → Production databases
Namespace: staging     → Staging databases
Namespace: development → Development databases
```

### 3. Isolamento por Aplicação

```
Namespace: app-ecommerce  → E-commerce databases
Namespace: app-auth       → Authentication databases
Namespace: app-analytics  → Analytics databases
```

### 4. Multi-Tenancy

```
Namespace: tenant-acme    → ACME Corp databases
Namespace: tenant-globex  → Globex databases
Namespace: tenant-initech → Initech databases
```

---

## 🔍 Troubleshooting

Veja o arquivo [07-troubleshooting.md](./07-troubleshooting.md) para guia completo de troubleshooting.

---

## 📚 Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `01-operator-rbac.yaml` | RBAC para operator gerenciar múltiplos namespaces |
| `02-consumer-namespaces.yaml` | Criação dos consumer namespaces |
| `03-consumer-rbac.yaml` | RBAC nos consumer namespaces |
| `04-redb-production.yaml` | REDB para produção |
| `05-redb-staging.yaml` | REDB para staging |
| `06-redb-development.yaml` | REDB para desenvolvimento |
| `07-troubleshooting.md` | Guia de troubleshooting |

---

## 🔗 Referências

- [Documentação Oficial - Multi-Namespace](https://redis.io/docs/latest/operate/kubernetes/reference/yaml/multi-namespace/)
- [Manage Databases in Multiple Namespaces](https://redis.io/docs/latest/operate/kubernetes/7.4.6/re-clusters/multi-namespace/)
- [RBAC Configuration](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

