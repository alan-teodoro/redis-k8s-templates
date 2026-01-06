# Best Practices for Redis Enterprise on Kubernetes

Comprehensive best practices guide for production Redis Enterprise deployments on Kubernetes.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Security](#security)
- [High Availability](#high-availability)
- [Performance](#performance)
- [Operations](#operations)
- [Monitoring](#monitoring)
- [Cost Optimization](#cost-optimization)

---

## 🏗️ Architecture

### Cluster Design

✅ **DO:**
- Use minimum 3 nodes (pods) for quorum - **ALWAYS**
- Deploy across multiple availability zones
- Use pod anti-affinity to spread pods (enabled by default)
- **Always have a spare Kubernetes node available in the same AZ** to schedule REC pods when a node is lost
- Separate namespaces for different environments
- **Use one namespace per REC** (one Redis Enterprise Operator per namespace)
- Use dedicated node pools for Redis workloads
- Know that there will **always only be one RE pod per K8s node** (anti-affinity)
- Know that the **pod disruption budget corresponds to quorum**
- **Practice generating logs using log_collector script** before you run into issues
- Enable rack-zone awareness for improved availability during zone failures
- Ensure **Guaranteed QoS** by setting limits = requests for CPU and memory

❌ **DON'T:**
- Run single-node clusters in production
- Deploy all pods in same zone
- Mix Redis with other critical workloads
- Use default namespace
- **NEVER scale REC StatefulSet to 0** (never stop all pods)
- **NEVER make any changes to the REC's StatefulSet directly**
- **NEVER take an RE pod down before all RE pods are fully ready**

### Rack-Zone Awareness

✅ **DO:**
- Enable rack awareness with `rackAwarenessNodeLabel: topology.kubernetes.io/zone`
- Ensure ALL eligible nodes have the topology label
- Grant operator ClusterRole to read node labels
- Use standard `topology.kubernetes.io/zone` label (set by most platforms)

⚠️ **IMPORTANT LIMITATION:**
- **Pod restart distribution is NOT maintained automatically**
- After pod restarts, rack awareness policy may be violated
- Manual intervention required to restore proper shard distribution
- Redis Enterprise provides tools to identify shards needing redistribution
- No automated orchestration for shard moves
- **Plan operational procedures** for handling rack awareness violations
- **Critical for edge deployments** where automated recovery is preferred
- **Monitor for rack awareness constraint violations** after pod restarts

❌ **DON'T:**
- Enable rack awareness without labeling all eligible nodes (reconciliation will fail)
- Assume rack distribution is maintained after pod restarts
- Deploy at scale without operational procedures for shard redistribution

### Database Design

✅ **DO:**
- Enable replication for all production databases
- Use appropriate eviction policies
- Set memory limits with 20% buffer
- Use sharding for datasets > 50GB
- Enable persistence (AOF) for critical data
- **When creating a DB using REDB, the REDB manifest is the source of truth**
- **Database changes MUST be made in the REDB manifest**, not in the UI or API
- Exception: Changes not yet supported in REDB CRD can be made via UI/API
- **Deploy the REDB admission controller** - it is highly recommended (automatically deployed if OLM is used)

❌ **DON'T:**
- Disable replication in production
- Use no-eviction without monitoring
- Set memory limits too tight
- Use single shard for large datasets
- Disable persistence for important data
- **NEVER use Admin UI to create databases** - always use REDB CRD for GitOps compatibility

---

## 🔐 Security

### Authentication & Authorization

✅ **DO:**
- Use strong passwords (External Secrets Operator)
- Enable TLS for all connections
- Use RBAC for Kubernetes access
- Implement network policies
- Enable audit logging

❌ **DON'T:**
- Store passwords in Git
- Use default passwords
- Allow unencrypted connections
- Grant cluster-admin to everyone
- Disable audit logs

### Network Security

✅ **DO:**
- Implement default-deny network policies
- Use TLS/mTLS for all traffic
- Restrict ingress to specific namespaces
- Use private subnets for Redis nodes
- Enable Pod Security Standards

❌ **DON'T:**
- Allow all traffic by default
- Use unencrypted connections
- Expose Redis to public internet
- Run pods as root
- Disable security contexts

---

## 🔄 High Availability

### Cluster Configuration

✅ **DO:**
- Deploy 3+ nodes across zones
- Enable automatic failover
- **Use persistent volumes with replication (block storage only)**
- Configure pod disruption budgets
- Test failover procedures regularly
- **Minimum pod size: 4000m CPU and 15GB memory**
- **Use EBS volumes in the same Availability Zone as the hosts** (AWS)
- Ensure Kubernetes worker nodes use NTP for clock synchronization

❌ **DON'T:**
- Use 2-node clusters (no quorum)
- Disable automatic failover
- Use local storage only
- Skip failover testing
- Ignore backup procedures
- **NEVER use NFS storage for persistence** - only block storage (EBS, PD, Azure Disk)
- **NEVER change PVC after deployment** (possible from 7.4+, but avoid)

### Storage Configuration

✅ **DO:**
- **Use block storage only** (EBS, Azure Managed Disks, GCP Persistent Disks)
- Use EXT4 or XFS file systems
- **Omit volumeSize** in REC spec (defaults to 5x memory - recommended)
- Use appropriate storage classes per cloud:
  - AWS: `gp3` (recommended) or `gp2`
  - GCP: `standard` or `pd-ssd`
  - Azure: `managed-premium` (SSD) or `default` (HDD)
- Verify storage class supports volume expansion (`AllowVolumeExpansion: true`)
- Calculate volume size: **5x memory size** (e.g., 15GB memory = 75GB volume)

❌ **DON'T:**
- **NEVER use NFS, NFS-like, or multi-read-write storage** (causes locking issues)
- **NEVER use shared storage** (incompatible with database requirements)
- Change storage class after deployment (not supported)
- Use volumeSize smaller than 5x memory
- Reduce PVC size after creation (not supported)

### Disaster Recovery

✅ **DO:**
- Automate backups (every 6-12 hours)
- Store backups in different region
- Test restore procedures quarterly
- Document runbooks
- Monitor backup success/failure

❌ **DON'T:**
- Rely on manual backups
- Store backups in same region only
- Skip restore testing
- Assume backups work without testing
- Ignore backup failures

---

## ⚡ Performance

### Resource Allocation

✅ **DO:**
- Set appropriate CPU/memory requests
- Use resource limits to prevent noisy neighbors
- **Set limits = requests for Guaranteed QoS** (prevents eviction)
- Monitor resource usage continuously
- Scale proactively based on trends
- Use node affinity for performance-critical workloads
- **Use PriorityClass** to prevent preemption by lower-priority workloads
- Configure eviction thresholds appropriately (soft > hard)
- Monitor node conditions (MemoryPressure, DiskPressure)

❌ **DON'T:**
- Omit resource requests/limits
- Over-provision resources wastefully
- Wait for performance issues to scale
- Ignore resource usage trends
- Mix performance tiers on same nodes
- Use Burstable or Best Effort QoS for production (risk of eviction)

### Database Optimization

✅ **DO:**
- Use pipelining for bulk operations
- Enable connection pooling
- Use appropriate data structures
- Monitor slow queries
- Optimize key naming patterns

❌ **DON'T:**
- Send commands one-by-one
- Create new connections per request
- Use inefficient data structures
- Ignore slow query logs
- Use very long key names

---

## 🖥️ Node Management

### Node Selection & Isolation

✅ **DO:**
- Use **nodeSelector** to target specific node pools or high-memory nodes
- Use **taints + tolerations** to reserve nodes exclusively for Redis Enterprise
- Label nodes appropriately before deployment
- Use dedicated node pools for production Redis workloads
- Combine nodeSelector + tolerations for strict isolation
- Verify pod placement after deployment

❌ **DON'T:**
- Mix Redis Enterprise with other critical workloads on same nodes
- Forget to label nodes before using nodeSelector
- Use taints without corresponding tolerations in REC spec

### Quality of Service (QoS)

✅ **DO:**
- Ensure **Guaranteed QoS** by setting limits = requests for CPU and memory
- Verify QoS class: `kubectl get pod rec-0 -o jsonpath="{.status.qosClass}"`
- Apply same limits = requests to sidecar containers
- Monitor for pod evictions

❌ **DON'T:**
- Use Burstable QoS (limits > requests) for production
- Use Best Effort QoS (no limits/requests) - pods will be evicted first
- Forget to check sidecar container resources

### Eviction Thresholds

✅ **DO:**
- Set **soft eviction threshold HIGHER** than hard eviction threshold
  - Example: soft=85%, hard=90% (soft triggers earlier warning)
- Set **eviction-soft-grace-period** high enough for administrator to scale cluster
  - Recommended: 5-10 minutes minimum
- Set **eviction-max-pod-grace-period** high enough for Redis to migrate databases
  - Recommended: 10-15 minutes minimum
- Configure platform-specific eviction settings:
  - **OpenShift**: Edit kubelet config file
  - **GKE**: Use managed settings in node pool config
  - **EKS**: Configure kubelet via user data or launch template
- Monitor node conditions (MemoryPressure, DiskPressure)
  - Command: `kubectl get nodes -o jsonpath='{range .items[*]}name:{.metadata.name}{"\t"}MemoryPressure:{.status.conditions[?(@.type == "MemoryPressure")].status}{"\t"}DiskPressure:{.status.conditions[?(@.type == "DiskPressure")].status}{"\n"}{end}'`

❌ **DON'T:**
- Use default eviction thresholds without review
- Set grace periods too low (causes forced pod termination)
- Ignore MemoryPressure or DiskPressure warnings
- Set soft threshold lower than hard threshold (defeats early warning purpose)

### Resource Quotas

✅ **DO:**
- Apply ResourceQuota to prevent runaway resource consumption
- Calculate quota based on: REC nodes + operator + databases + buffer
- **Operator minimum resources:**
  - CPU: 500m (0.5 cores)
  - Memory: 256Mi
- **Example calculation for 3-node REC:**
  - REC nodes: 3 × 4000m CPU + 3 × 15Gi memory = 12000m CPU + 45Gi memory
  - Operator: 500m CPU + 256Mi memory
  - Buffer (20%): 2500m CPU + 9Gi memory
  - **Total quota: 15000m CPU + 54Gi memory**
- Monitor quota usage regularly
- Adjust quota as workload grows

❌ **DON'T:**
- Deploy without resource quotas in multi-tenant environments
- Set quota too tight (prevents scaling)
- Forget to include operator resources in quota calculations
- Forget to include buffer for overhead and scaling

---

## 🔧 Operations

### Deployment

✅ **DO:**
- Use GitOps (ArgoCD) for deployments
- Version all configurations
- Test in non-production first
- Use rolling updates
- Have rollback procedures

❌ **DON'T:**
- Apply changes manually
- Skip version control
- Deploy directly to production
- Use recreate strategy
- Deploy without rollback plan

### Maintenance

✅ **DO:**
- Schedule maintenance windows
- Communicate changes in advance
- Monitor during maintenance
- Verify health after changes
- Document all changes
- **Drain nodes one at a time** (maintain quorum)
- **Wait for all pods to be ready** before proceeding to next node
- **Set operator upgrades to manual** (especially on OpenShift OLM)

❌ **DON'T:**
- Perform unscheduled maintenance
- Make changes without notice
- Skip post-change verification
- Forget to document changes
- Rush through maintenance
- **NEVER use automatic operator upgrades on OpenShift OLM** (set to manual)
- **NEVER drain multiple nodes simultaneously** (breaks quorum)

---

## 📊 Monitoring

### Metrics

✅ **DO:**
- Monitor all key metrics (CPU, memory, OPS, latency)
- Set up alerts for critical thresholds
- Use Grafana dashboards
- Track trends over time
- Monitor backup success/failure

❌ **DON'T:**
- Monitor only basic metrics
- Skip alerting setup
- Rely on manual checks
- Ignore historical trends
- Forget backup monitoring

### Logging

✅ **DO:**
- Centralize logs (Loki/EFK)
- Set appropriate log levels
- Retain logs per compliance needs
- Monitor for errors
- Use structured logging

❌ **DON'T:**
- Rely on pod logs only
- Use DEBUG in production
- Delete logs immediately
- Ignore error logs
- Use unstructured logs

---

## 💰 Cost Optimization

### Resource Efficiency

✅ **DO:**
- Right-size resources based on usage
- Use spot/preemptible instances for non-critical
- Enable cluster autoscaling
- Use appropriate storage classes
- Monitor and optimize costs regularly

❌ **DON'T:**
- Over-provision resources
- Use on-demand for everything
- Keep unused resources
- Use premium storage unnecessarily
- Ignore cost trends

### Data Management

✅ **DO:**
- Use eviction policies appropriately
- Set TTLs on temporary data
- Archive old data to object storage
- Compress backups
- Clean up unused databases

❌ **DON'T:**
- Keep all data in memory forever
- Store temporary data permanently
- Keep all backups indefinitely
- Store uncompressed backups
- Leave zombie databases running

---

## 📚 Quick Reference Checklist

### Pre-Production Checklist

- [ ] 3+ node cluster across zones
- [ ] Replication enabled for all databases
- [ ] TLS enabled for all connections
- [ ] Network policies configured
- [ ] RBAC configured
- [ ] External Secrets Operator configured
- [ ] Monitoring and alerting set up
- [ ] Logging centralized
- [ ] Backup automation configured
- [ ] Disaster recovery tested
- [ ] Resource limits set
- [ ] Pod Security Standards enforced
- [ ] Documentation complete
- [ ] Runbooks created
- [ ] Team trained

### Production Checklist

- [ ] All pre-production items complete
- [ ] Load testing completed
- [ ] Failover testing completed
- [ ] Backup restore tested
- [ ] Monitoring dashboards reviewed
- [ ] Alerts configured and tested
- [ ] On-call rotation established
- [ ] Incident response plan documented
- [ ] Capacity planning completed
- [ ] Cost optimization reviewed

---

## 📚 Related Documentation

- **[Validation Runbook](VALIDATION-RUNBOOK.md)** - Step-by-step commands to test and validate each best practice
- **[Implementation Review Guide](IMPLEMENTATION-REVIEW-GUIDE.md)** - Complete meeting preparation guide for Redis Enterprise implementation reviews (AWS EKS | GCP GKE | Azure AKS | OpenShift)
- [Security](../security/README.md)
- [HA & Disaster Recovery](../operations/ha-disaster-recovery/README.md)
- [Monitoring](../observability/monitoring/README.md)
- [Capacity Planning](../operations/capacity-planning/README.md)

---

## 🔗 References

- Redis Enterprise Best Practices: https://redis.io/docs/latest/operate/rs/installing-upgrading/install/plan-deployment/
- Kubernetes Best Practices: https://kubernetes.io/docs/concepts/configuration/overview/

