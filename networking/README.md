# Redis Enterprise Networking

External access configurations for Redis Enterprise on Kubernetes.

**Platform-agnostic:** Works on EKS, GKE, AKS, and vanilla Kubernetes.

---

## 📋 Overview

This directory contains configurations for exposing Redis Enterprise Cluster (REC) UI and databases externally using various networking solutions.

### What Needs External Access?

1. **REC UI (API)** - Port 8443 (HTTPS)
   - Web-based management interface
   - REST API for automation
   - Requires TLS termination or passthrough

2. **Redis Databases** - Custom ports (e.g., 12000)
   - Client connections to databases
   - Requires TLS passthrough (SNI-based routing)
   - Each database needs unique external endpoint

---

## 🌐 Networking Solutions

### 1. Gateway API (Recommended)

**See:** [gateway-api/](gateway-api/)

Modern Kubernetes networking API (successor to Ingress).

**Implementations:**
- **NGINX Gateway Fabric** - [gateway-api/nginx-gateway-fabric/](gateway-api/nginx-gateway-fabric/)
- **Istio Gateway** - [gateway-api/istio/](gateway-api/istio/) 🚧 Coming soon

**Use cases:**
- Modern Kubernetes clusters (1.26+)
- Advanced routing requirements
- TLS passthrough for databases
- Multi-protocol support (HTTP, TLS, TCP)

**Pros:**
- ✅ Modern, standardized API
- ✅ Better than Ingress for complex routing
- ✅ Native TLS passthrough support
- ✅ Role-based access control

**Cons:**
- ❌ Requires Gateway API CRDs installation
- ❌ Not all clusters support it yet

---

### 2. Ingress (NGINX Ingress Controller)

**See:** [ingress/nginx/](ingress/nginx/)

Traditional Kubernetes Ingress with NGINX.

**Use cases:**
- Clusters without Gateway API support
- Simple HTTP/HTTPS routing
- Wide compatibility

**Pros:**
- ✅ Widely supported
- ✅ Mature and stable
- ✅ Works on most Kubernetes versions

**Cons:**
- ❌ Limited TLS passthrough support
- ❌ TCP/UDP requires ConfigMap configuration
- ❌ Less flexible than Gateway API

---

### 3. HAProxy Ingress

**See:** [ingress/haproxy/](ingress/haproxy/)

HAProxy-based Ingress controller.

**Use cases:**
- High-performance requirements
- Advanced load balancing
- TCP/TLS passthrough

**Pros:**
- ✅ High performance
- ✅ Advanced load balancing features
- ✅ Good TLS passthrough support

**Cons:**
- ❌ Less common than NGINX
- ❌ More complex configuration

---

### 4. Istio Service Mesh

**See:** [service-mesh/istio/](service-mesh/istio/)

Full-featured service mesh with advanced traffic management.

**Use cases:**
- Microservices architectures
- Advanced observability requirements
- mTLS between services
- Complex traffic routing

**Pros:**
- ✅ Advanced traffic management
- ✅ Built-in observability
- ✅ mTLS support
- ✅ Circuit breaking, retries, timeouts

**Cons:**
- ❌ Complex setup
- ❌ Higher resource overhead
- ❌ Steeper learning curve

---

### 5. In-Cluster Access (No External Access)

**See:** [in-cluster/](in-cluster/)

Access Redis Enterprise from within the Kubernetes cluster only.

**Use cases:**
- Development and testing
- Applications running in the same cluster
- Security-sensitive environments

**Pros:**
- ✅ Simple setup
- ✅ No external exposure
- ✅ Better security

**Cons:**
- ❌ No external access
- ❌ Requires VPN or bastion for management

---

## 🎯 Decision Matrix

| Solution | Complexity | Performance | TLS Passthrough | Modern | Recommended For |
|----------|------------|-------------|-----------------|--------|-----------------|
| **Gateway API (NGINX)** | Medium | High | ✅ Excellent | ✅ Yes | New deployments |
| **NGINX Ingress** | Low | High | ⚠️ Limited | ❌ No | Legacy clusters |
| **HAProxy Ingress** | Medium | Very High | ✅ Good | ❌ No | High performance |
| **Istio** | High | Medium | ✅ Excellent | ✅ Yes | Service mesh users |
| **In-Cluster** | Very Low | N/A | N/A | N/A | Dev/Test |

---

## 🚀 Quick Start

### For New Deployments (Recommended)

Use **Gateway API with NGINX Gateway Fabric**:

```bash
cd gateway-api/nginx-gateway-fabric/
# Follow README.md
```

### For Existing Clusters

Use **NGINX Ingress Controller**:

```bash
cd ingress/nginx/
# Follow README.md
```

---

## 📚 Additional Resources

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [HAProxy Ingress](https://haproxy-ingress.github.io/)
- [Istio](https://istio.io/)

