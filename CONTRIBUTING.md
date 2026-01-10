# Contributing to Redis Enterprise on Kubernetes Reference Repository

## Documentation Standards

- **Language:** English only
- **Style:** Clear, step-by-step instructions (see `platforms/openshift/` as gold standard)
- **Format:** Concise, reference-focused (no conceptual explanations)
- **Testing:** All configurations must be tested before committing

## README Template

```markdown
# [Component Name]

Brief description (1-2 sentences).

## Prerequisites
- Requirement 1
- Requirement 2

## Step-by-Step Deployment

### Step 1: [Action]
```bash
command
```

**Expected output:**
```
output
```

## Verification
How to verify it's working

## Troubleshooting
Common issues and solutions
```

## YAML Standards

- All comments in English
- Explain WHY, not just WHAT
- Include expected values and ranges

## Best Practices

- ✅ Use clear, imperative language
- ✅ Include verification steps after each action
- ✅ Provide realistic examples
- ✅ Keep it concise and scannable
- ❌ No automation scripts - use manual steps
- ❌ No untested configurations
- ❌ No sensitive data in files

