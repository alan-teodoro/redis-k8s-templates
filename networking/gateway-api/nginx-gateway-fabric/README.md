# NGINX Gateway Fabric

Official successor to NGINX Ingress Controller (retiring March 2026).

---

## Installation

```bash
# 1. Install Gateway API CRDs (Experimental Channel for TLSRoute)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f -

# 2. Install NGINX Gateway Fabric with experimental features enabled
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace \
  --namespace nginx-gateway \
  --set nginxGateway.gwAPIExperimentalFeatures.enable=true

# 3. Verify
kubectl get gatewayclass
kubectl get pods -n nginx-gateway
kubectl get crd tlsroutes.gateway.networking.k8s.io
```

---

## REC UI Access

### 1. Create TLS Certificate

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.redis.example.com/O=Redis"

# Create secret
kubectl create secret tls redis-tls-cert \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  -n nginx-gateway

# Cleanup
rm /tmp/tls.key /tmp/tls.crt
```

### 2. Extract Backend CA

```bash
kubectl exec -n redis-enterprise rec-0 -c redis-enterprise-node -- \
  openssl s_client -connect rec-ui.redis-enterprise.svc.cluster.local:8443 -showcerts </dev/null 2>/dev/null | \
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > rec-ui-cert.pem

kubectl create configmap rec-backend-ca-cert \
  --from-file=ca.crt=rec-ui-cert.pem \
  -n redis-enterprise
```

### 3. Create Gateway

```bash
kubectl apply -f gateway.yaml

# Wait
kubectl wait --for=condition=programmed gateway/redis-gateway -n nginx-gateway --timeout=5m

# Get IP
GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)
```

### 4. Create BackendTLSPolicy

```bash
kubectl apply -f backend-tls-policy.yaml
```

### 5. Create HTTPRoute

```bash
kubectl apply -f httproute-rec-ui.yaml
```

### 6. Test

```bash
# curl
curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/

# Browser
echo "$GATEWAY_IP ui.redis.example.com" | sudo tee -a /etc/hosts
open https://ui.redis.example.com
```

**Credentials:**
- User: `demo@redis.com`
- Pass: `kubectl get secret rec -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d`

---

## Database Access (TLS Passthrough)

### 1. Create Gateway

Gateway includes:
- HTTP listener (port 80)
- HTTPS listener with TLS termination (port 443) for REC UI
- TLS passthrough listener (port 6379) for databases
- AWS NLB annotation for better TLS passthrough support

```bash
kubectl apply -f gateway.yaml
kubectl wait --for=condition=programmed gateway/redis-gateway -n nginx-gateway --timeout=5m
```

**Note:** Gateway creates AWS Network Load Balancer (NLB). Wait 2-3 minutes for provisioning.

### 2. Create TLSRoute

```bash
kubectl apply -f tlsroute-database.yaml
kubectl get tlsroute redis-db-tls-route -n redis-enterprise
```

### 3. Test Connection

```bash
# Get Gateway IP
GATEWAY_HOSTNAME=$(kubectl get gateway redis-gateway -n nginx-gateway -o jsonpath='{.status.addresses[0].value}')
GATEWAY_IP=$(dig +short $GATEWAY_HOSTNAME | head -1)

# Get database password
DB_PASSWORD=$(kubectl get secret redb-test-db -n redis-enterprise -o jsonpath='{.data.password}' | base64 -d)

# Test with redis-cli (requires SNI support)
redis-cli -h db.redis.example.com -p 6379 --tls --sni db.redis.example.com --insecure -a $DB_PASSWORD PING

# Add to /etc/hosts for testing
echo "$GATEWAY_IP db.redis.example.com" | sudo tee -a /etc/hosts
```

---

## Troubleshooting

### 421 Misdirected Request

Use `--resolve` instead of `-H "Host:"`:

```bash
curl -k --resolve ui.redis.example.com:443:$GATEWAY_IP https://ui.redis.example.com/
```

### 502 Bad Gateway

Check NGINX logs for SSL errors:

```bash
NGINX_POD=$(kubectl get pods -n nginx-gateway -o name | grep redis-gateway-nginx)
kubectl logs -n nginx-gateway $NGINX_POD --tail=50
```

If `upstream SSL certificate verify error`, re-extract backend certificate.

---

## References

- [Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [NGINX Ingress Retirement](https://kubernetes.io/blog/2024/12/ingress-nginx-retirement/)

