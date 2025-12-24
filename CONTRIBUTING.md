# Contributing to Redis Enterprise on Kubernetes Reference Repository

This guide explains how to add content to this reference repository.

## Documentation Style

Follow the **OpenShift examples** as the gold standard:
- See `platforms/openshift/single-region/` for excellent documentation style
- Clear, step-by-step instructions
- Concise, reference-focused (no conceptual explanations)
- Practical, tested configurations

## Directory Structure Standards

Each major section should have:

```
section-name/
├── README.md           # Overview, quick start, navigation
├── subsection-1/
│   ├── README.md       # Specific guide for this subsection
│   ├── *.yaml          # YAML configurations
│   └── steps.txt       # Optional: step-by-step commands
└── subsection-2/
    └── ...
```

## README.md Template

Every README.md should include:

```markdown
# [Section Name]

Brief description (1-2 sentences).

## Overview

What this section covers (bullet points).

## Directory Structure

```
section/
├── file1.yaml
└── file2.yaml
```

## Prerequisites

- Requirement 1
- Requirement 2

## Quick Start / Deployment Steps

Step-by-step instructions with commands.

## Configuration Options

Key configuration parameters.

## Verification

How to verify it's working.

## Troubleshooting

Common issues and solutions.

## Next Steps

What to do after completing this section.
```

## YAML File Standards

### File Naming
- Use descriptive names: `storageclass-gp3.yaml` not `sc.yaml`
- Number files if order matters: `01-namespace.yaml`, `02-secret.yaml`
- Use lowercase with hyphens: `redis-cluster.yaml` not `RedisCluster.yaml`

### File Content
- Include comments explaining key parameters
- Use realistic values (not `changeme` or `example.com`)
- Include namespace in metadata
- Add labels for organization

Example:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-admin-secret
  namespace: redis-system
  labels:
    app: redis-enterprise
type: Opaque
stringData:
  # Change these credentials for production
  username: admin@redis.com
  password: RedisAdmin123!
```

## Step-by-Step Guides

For deployment guides, use this format:

```markdown
## Deployment Steps

### Prerequisites
- List prerequisites
- Include verification commands

### Step 1: [Action]
```bash
# Command with explanation
kubectl apply -f file.yaml
```

**Verify:**
```bash
kubectl get pods -n namespace
```

### Step 2: [Next Action]
...
```

## Testing Requirements

Before submitting content:

1. **Test all YAML files** in a real cluster
2. **Verify all commands** work as documented
3. **Check for typos** and formatting issues
4. **Ensure links** work correctly

## Platform-Specific Content

When adding platform-specific content (EKS, AKS, GKE):

### Required Sections
1. **Storage** - CSI drivers, storage classes, PVC examples
2. **Networking** - Load balancers, ingress, security groups/NSG/firewall
3. **Identity** - IAM/Managed Identity/Workload Identity
4. **Examples** - Complete end-to-end deployments

### Platform Naming
- Use official names: EKS (not "AWS Kubernetes"), AKS (not "Azure Kubernetes")
- Reference official documentation
- Include version requirements

## Integration Content

When adding integration content (Vault, ArgoCD, cert-manager):

1. **Installation** - How to install the integration
2. **Configuration** - How to configure it for Redis
3. **Examples** - Working examples with Redis Enterprise
4. **Troubleshooting** - Common issues

## Code Examples

### Bash Scripts
- Include shebang: `#!/bin/bash`
- Add error handling: `set -e`
- Comment complex sections
- Make executable: `chmod +x script.sh`

### Kubernetes Manifests
- Validate with `kubectl apply --dry-run=client`
- Use `---` to separate resources in multi-resource files
- Include resource limits and requests
- Add appropriate labels and annotations

## Documentation Best Practices

### Do:
- ✅ Use clear, imperative language ("Create a namespace", not "You should create")
- ✅ Include verification steps after each major action
- ✅ Provide realistic examples
- ✅ Link to official documentation for deep dives
- ✅ Keep it concise and scannable

### Don't:
- ❌ Explain basic Kubernetes concepts (assume knowledge)
- ❌ Use placeholder values without explanation
- ❌ Include untested configurations
- ❌ Write long paragraphs (use bullets and code blocks)
- ❌ Duplicate content (link to existing docs instead)

## Updating the Roadmap

When you complete content:
1. Update `ROADMAP.md`
2. Change `[ ]` to `[x]` for completed items
3. Add any new items discovered during work

## Review Checklist

Before considering content complete:

- [ ] README.md exists and follows template
- [ ] All YAML files are tested and working
- [ ] Commands are verified in a real cluster
- [ ] No sensitive data (passwords, API keys) in files
- [ ] Links are working
- [ ] Formatting is consistent
- [ ] Spelling and grammar checked
- [ ] ROADMAP.md updated

## Questions?

This is a collaborative reference repository. If you're unsure about:
- Structure: Look at `platforms/openshift/` examples
- Style: Follow existing documentation patterns
- Content: Check with the team

## Example: Adding New Platform Content

Let's say you're adding content for EKS storage:

1. **Create directory**: `platforms/eks/storage/`
2. **Add README.md**: Follow template above
3. **Add YAML files**: 
   - `storageclass-gp3.yaml`
   - `storageclass-io2.yaml`
   - `pvc-example.yaml`
4. **Test everything**: Deploy in real EKS cluster
5. **Update roadmap**: Mark EKS storage as complete
6. **Commit**: Clear commit message

## Commit Message Format

```
[Section] Brief description

- Detailed change 1
- Detailed change 2

Tested on: [platform/version]
```

Example:
```
[EKS] Add storage configuration examples

- Added gp3 and io2 storage class examples
- Included PVC examples with annotations
- Added README with EBS CSI driver setup

Tested on: EKS 1.28 with EBS CSI driver 1.25.0
```

