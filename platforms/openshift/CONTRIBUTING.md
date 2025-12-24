# Contributing to Redis Enterprise OpenShift Templates

This guide is for consultants and engineers who want to customize or extend these templates for customer deployments.

## 📋 Template Philosophy

These templates are designed to be:
- **Educational**: Clear, well-documented examples
- **Customizable**: Easy to adapt for specific customer needs
- **Production-ready**: Following Redis Enterprise best practices
- **Manual**: Emphasizing understanding over automation

## 🎯 For Consultants

### Before Customer Engagement

1. **Review the templates** thoroughly
2. **Test in a lab environment** to understand the deployment flow
3. **Customize for customer** requirements (sizing, security, etc.)
4. **Update credentials** - never use default passwords
5. **Prepare customer-specific documentation**

### During Deployment

1. **Walk through each step** with the customer
2. **Explain the purpose** of each YAML file
3. **Verify each step** before proceeding
4. **Document any customizations** made
5. **Test thoroughly** before handing over

### Customization Checklist

- [ ] Update cluster domains in all YAML files
- [ ] Change default credentials (see SECRETS.md)
- [ ] Adjust resource requests/limits based on sizing
- [ ] Configure storage class if needed
- [ ] Enable/disable TLS based on requirements
- [ ] Configure monitoring and alerting
- [ ] Set up backup procedures
- [ ] Document customer-specific changes

## 🔧 Common Customizations

### Sizing Adjustments

**Small Deployment (Dev/Test):**
```yaml
nodes: 3
redisEnterpriseNodeResources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 2
    memory: 4Gi
```

**Medium Deployment (Production):**
```yaml
nodes: 3
redisEnterpriseNodeResources:
  requests:
    cpu: 4
    memory: 16Gi
  limits:
    cpu: 4
    memory: 16Gi
```

**Large Deployment (High Performance):**
```yaml
nodes: 5
redisEnterpriseNodeResources:
  requests:
    cpu: 8
    memory: 32Gi
  limits:
    cpu: 8
    memory: 32Gi
```

### Database Configurations

**High Availability:**
```yaml
spec:
  memorySize: 1GB
  shardCount: 2
  replication: true      # Enables replica
  rackAware: true        # Distributes across zones
```

**High Performance:**
```yaml
spec:
  memorySize: 10GB
  shardCount: 4
  replication: true
  proxyPolicy: all-master-shards
```

**With Redis Modules:**
```yaml
spec:
  modulesList:
    - name: search
      version: 2.10.10
    - name: rejson
      version: 2.8.10
    - name: timeseries
      version: 1.12.3
```

### Storage Configuration

**For high IOPS requirements:**
```yaml
persistentSpec:
  enabled: true
  storageClassName: fast-ssd
  volumeSize: 100Gi
```

### Network Configuration

**Custom domain:**
```yaml
ingressOrRouteSpec:
  method: openShiftRoute
  apiFqdnUrl: api-redis.customer.example.com
  dbFqdnSuffix: -db-redis.customer.example.com
```

## 📝 Adding New Examples

If you create useful configurations for specific use cases:

1. Create a new directory under the relevant section
2. Add a README.md explaining the use case
3. Include all necessary YAML files
4. Document any prerequisites or special considerations
5. Test thoroughly before sharing

Example structure:
```
single-region/
└── examples/
    ├── high-availability/
    │   ├── README.md
    │   └── redb-ha.yaml
    └── with-modules/
        ├── README.md
        └── redb-modules.yaml
```

## 🐛 Reporting Issues

If you encounter issues or have suggestions:

1. Document the issue clearly
2. Include environment details (OpenShift version, operator version)
3. Provide steps to reproduce
4. Share any error messages or logs
5. Suggest improvements if possible

## 🔒 Security Considerations

When customizing for customers:

1. **Never commit actual credentials** to version control
2. **Use customer-specific secrets** for each deployment
3. **Enable TLS** for production deployments
4. **Configure RBAC** appropriately
5. **Follow customer security policies**
6. **Document security configurations**

## 📚 Best Practices

### Documentation

- Keep README files up to date
- Document all customizations
- Include troubleshooting steps
- Provide examples for common scenarios

### Testing

- Test in non-production first
- Verify all steps work as documented
- Test rollback procedures
- Validate monitoring and alerting

### Customer Handover

- Provide complete documentation
- Train customer team on operations
- Document backup/restore procedures
- Establish support escalation path
- Share relevant Redis Enterprise resources

## 🤝 Sharing Improvements

If you develop improvements that would benefit other consultants:

1. Test thoroughly in multiple environments
2. Document clearly with examples
3. Follow the existing template structure
4. Share with the team for review
5. Update this repository with approved changes

## 📞 Support Resources

- **Redis Enterprise Documentation**: https://redis.io/docs/latest/operate/kubernetes/
- **OpenShift Documentation**: https://docs.openshift.com/
- **Redis Support Portal**: For enterprise support cases
- **Internal Team**: Reach out to experienced colleagues

---

**Remember**: These templates are starting points. Every customer deployment is unique and may require customization. Use your expertise and judgment to adapt these templates to meet specific customer needs while following Redis Enterprise best practices.

