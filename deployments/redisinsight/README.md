# RedisInsight on Kubernetes

**RedisInsight** is Redis' official GUI tool for managing and monitoring Redis databases. This guide shows how to deploy RedisInsight on Kubernetes.

---

## 📋 Overview

RedisInsight provides:
- **Database Management**: Connect to Redis Enterprise and OSS databases
- **Data Browser**: View and edit keys with rich data type support
- **CLI**: Built-in Redis CLI
- **Profiler**: Analyze commands in real-time
- **Slow Log**: Identify slow commands
- **Memory Analysis**: Analyze memory usage
- **RDI Integration**: Configure and monitor RDI pipelines

---

## 📁 Files in this Directory

| File | Description |
|------|-------------|
| `01-deployment-ephemeral.yaml` | RedisInsight with ephemeral storage (dev/test) |
| `02-deployment-persistent.yaml` | RedisInsight with persistent storage (production) |
| `03-service-loadbalancer.yaml` | LoadBalancer service |
| `04-service-clusterip.yaml` | ClusterIP service (with port-forward) |
| `05-ingress-nginx.yaml` | NGINX Ingress |
| `06-ingress-gateway-api.yaml` | Gateway API HTTPRoute |
| `07-openshift-route.yaml` | OpenShift Route |

---

## 🚀 Quick Start

### Option 1: Ephemeral Storage (Dev/Test)

```bash
# Deploy RedisInsight with ephemeral storage
kubectl apply -f 01-deployment-ephemeral.yaml

# Deploy LoadBalancer service
kubectl apply -f 03-service-loadbalancer.yaml

# Get external IP
kubectl get svc redisinsight-service -n redis-enterprise

# Access RedisInsight at http://<EXTERNAL-IP>
```

### Option 2: Persistent Storage (Production)

```bash
# Deploy RedisInsight with persistent storage
kubectl apply -f 02-deployment-persistent.yaml

# Deploy LoadBalancer service
kubectl apply -f 03-service-loadbalancer.yaml

# Get external IP
kubectl get svc redisinsight-service -n redis-enterprise

# Access RedisInsight at http://<EXTERNAL-IP>
```

### Option 3: Port Forward (No Service)

```bash
# Deploy RedisInsight
kubectl apply -f 01-deployment-ephemeral.yaml

# Port forward
kubectl port-forward deployment/redisinsight 5540:5540 -n redis-enterprise

# Access RedisInsight at http://localhost:5540
```

---

## 🔐 Security Considerations

### 1. Use Ingress with TLS

```bash
# Deploy with NGINX Ingress + TLS
kubectl apply -f 05-ingress-nginx.yaml

# Access at https://redisinsight.example.com
```

### 2. Network Policies

```bash
# Restrict access to RedisInsight
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redisinsight-netpol
  namespace: redis-enterprise
spec:
  podSelector:
    matchLabels:
      app: redisinsight
  policyTypes:
    - Ingress
  ingress:
    # Allow from ingress controller only
    - from:
        - namespaceSelector:
            matchLabels:
              name: nginx-ingress
      ports:
        - protocol: TCP
          port: 5540
EOF
```

### 3. Authentication

RedisInsight does not have built-in authentication. Use one of:
- **Ingress with OAuth2 Proxy**
- **VPN/Bastion access only**
- **Network Policies** to restrict access

---

## 📊 Connecting to Redis Databases

### Connect to Redis Enterprise Database

1. Open RedisInsight at http://<EXTERNAL-IP>
2. Click **"Add Redis Database"**
3. Select **"Add Database"**
4. Enter connection details:
   - **Host**: `<database-name>.redis-enterprise.svc.cluster.local`
   - **Port**: `12000` (or your database port)
   - **Database Alias**: `My Redis Database`
   - **Username**: `default` (if ACL enabled)
   - **Password**: Get from secret:
     ```bash
     kubectl get secret redb-<database-name> -n redis-enterprise \
       -o jsonpath='{.data.password}' | base64 -d
     ```

### Connect with TLS

1. Get TLS certificate:
   ```bash
   kubectl get secret <database-name>-cert -n redis-enterprise \
     -o jsonpath='{.data.proxy_cert}' | base64 -d > ca.crt
   ```
2. In RedisInsight:
   - Enable **"Use TLS"**
   - Upload `ca.crt` as CA Certificate

---

## 🔄 RDI Integration

RedisInsight has built-in RDI support:

1. Open RedisInsight
2. Go to **"RDI"** section
3. Add RDI instance:
   - **URL**: `https://rdi-api.rdi.svc.cluster.local:8080`
   - **Username**: (if configured)
   - **Password**: (if configured)

4. Configure pipelines via GUI
5. Monitor pipeline status and metrics

---

## 🔗 Useful Links

- [RedisInsight Documentation](https://redis.io/docs/latest/operate/redisinsight/)
- [RedisInsight RDI Guide](https://redis.io/docs/latest/operate/redisinsight/rdi/)
- [RedisInsight GitHub](https://github.com/RedisInsight/RedisInsight)

---

**Status**: ✅ Production Ready  
**RedisInsight Version**: latest  
**Namespace**: redis-enterprise

