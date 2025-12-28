# Logging for Redis Enterprise on Kubernetes

Complete logging solutions for Redis Enterprise deployments on Kubernetes.

## 📋 Table of Contents

- [Overview](#overview)
- [Logging Architecture](#logging-architecture)
- [Implementation Options](#implementation-options)
- [Log Types](#log-types)
- [Best Practices](#best-practices)

---

## 🎯 Overview

Centralized logging is critical for:
- ✅ Troubleshooting issues
- ✅ Performance analysis
- ✅ Security auditing
- ✅ Compliance requirements
- ✅ Operational insights

---

## 🏗️ Logging Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Logging Architecture                        │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐ │
│  │ Redis Pods   │ ───▶ │ Log Collector│ ───▶ │ Storage   │ │
│  │ (stdout/err) │      │ (Fluentd/    │      │ (Loki/    │ │
│  │              │      │  Fluent Bit) │      │  ES/S3)   │ │
│  └──────────────┘      └──────────────┘      └───────────┘ │
│                                                      │       │
│                                                      ▼       │
│                                              ┌──────────────┐│
│                                              │ Visualization││
│                                              │ (Grafana)    ││
│                                              └──────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Implementation Options

### 1. Loki + Promtail (Recommended)

**Best for:** Kubernetes-native, lightweight, integrates with Grafana

See: [loki/](loki/)

**Features:**
- ✅ Lightweight and efficient
- ✅ Native Grafana integration
- ✅ Label-based indexing
- ✅ Cost-effective storage

### 2. Elasticsearch + Fluentd + Kibana (EFK)

**Best for:** Advanced search, large-scale deployments

See: [efk/](efk/)

**Features:**
- ✅ Full-text search
- ✅ Advanced analytics
- ✅ Rich visualization
- ✅ Mature ecosystem

### 3. Fluent Bit + CloudWatch/Stackdriver

**Best for:** Cloud-native deployments (AWS/GCP)

See: [cloud-logging/](cloud-logging/)

**Features:**
- ✅ Native cloud integration
- ✅ Minimal resource usage
- ✅ Managed service
- ✅ Pay-as-you-go

---

## 📝 Log Types

### 1. Application Logs

Redis Enterprise application logs from pods.

**Location:** stdout/stderr of containers

**Examples:**
- Database operations
- Cluster events
- Replication status
- Error messages

### 2. Audit Logs

Security and compliance audit logs.

**Examples:**
- User authentication
- Configuration changes
- Database access
- Admin operations

### 3. System Logs

Kubernetes and infrastructure logs.

**Examples:**
- Pod lifecycle events
- Resource usage
- Network events
- Storage events

---

## ✅ Best Practices

### 1. **Centralized Logging**
- ✅ Collect all logs in one place
- ✅ Use structured logging (JSON)
- ✅ Include context (namespace, pod, container)

### 2. **Log Retention**
- ✅ Define retention policies
- ✅ Archive old logs to object storage
- ✅ Balance cost vs compliance needs

### 3. **Log Levels**
- ✅ Use appropriate log levels (DEBUG, INFO, WARN, ERROR)
- ✅ Avoid excessive DEBUG logging in production
- ✅ Configure log levels per component

### 4. **Security**
- ✅ Redact sensitive information (passwords, tokens)
- ✅ Encrypt logs in transit and at rest
- ✅ Control access to logs (RBAC)

### 5. **Performance**
- ✅ Use lightweight log collectors (Fluent Bit)
- ✅ Buffer logs to handle spikes
- ✅ Monitor collector resource usage

### 6. **Alerting**
- ✅ Alert on ERROR logs
- ✅ Alert on specific patterns (OOM, crashes)
- ✅ Integrate with incident management

---

## 🔍 Common Log Queries

### Find Errors

```
{namespace="redis-enterprise"} |= "ERROR"
```

### Database Operations

```
{namespace="redis-enterprise", app="redis-enterprise"} |= "database"
```

### Authentication Failures

```
{namespace="redis-enterprise"} |= "authentication failed"
```

### High Memory Usage

```
{namespace="redis-enterprise"} |= "memory" |= "high"
```

---

## 📚 Related Documentation

- [Monitoring](../monitoring/README.md) - Metrics and alerting
- [Tracing](../tracing/README.md) - Distributed tracing
- [Security](../../security/README.md) - Audit logging

---

## 🔗 References

- Grafana Loki: https://grafana.com/oss/loki/
- Fluentd: https://www.fluentd.org/
- Fluent Bit: https://fluentbit.io/
- Elasticsearch: https://www.elastic.co/elasticsearch/

