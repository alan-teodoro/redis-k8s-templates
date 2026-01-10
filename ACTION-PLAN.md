# Action Plan - Repository Simplification

**Goal:** Transform this repo into a simple, English-only, manual-steps reference for labs and client engagements.

---

## 📋 Phase 1: Critical Fixes (Priority 1)

### Task 1.1: Translate Vault Integration to English
**Estimated Time:** 2-3 hours

**Files to Translate:**
- [ ] `integrations/vault/README.md`
- [ ] `integrations/vault/vault-in-cluster/README.md` (296 lines)
- [ ] `integrations/vault/vault-in-cluster/QUICKSTART.md`
- [ ] `integrations/vault/external-vault/README.md` (498 lines)
- [ ] `integrations/vault/external-vault/SETUP_MANUAL.md`
- [ ] `integrations/vault/external-vault/TROUBLESHOOTING.md`

**Commands:**
```bash
# Review each file and translate Portuguese → English
# Focus on:
# - Section headers
# - Step descriptions
# - Comments
# - Warnings/notes
```

---

### Task 1.2: Remove vault-in-cluster Implementation
**Estimated Time:** 30 minutes

**Rationale:** 
- Rarely used in production
- Adds unnecessary complexity
- Official HashiCorp docs are better for this use case

**Actions:**
```bash
# Remove the entire vault-in-cluster directory
rm -rf integrations/vault/vault-in-cluster/

# Update integrations/vault/README.md to mention:
# "For in-cluster Vault deployment, refer to official HashiCorp Vault Helm chart documentation"
```

**Files to Remove:**
- [ ] `integrations/vault/vault-in-cluster/` (entire directory)

**Files to Update:**
- [ ] `integrations/vault/README.md` - Remove comparison, keep only external-vault reference

---

### Task 1.3: Convert Scripts to Manual Steps
**Estimated Time:** 2 hours

**Scripts to Convert:**

#### 1. `integrations/vault/vault-in-cluster/02-vault-init.sh`
**Action:** DELETE (removing vault-in-cluster)

#### 2. `integrations/vault/vault-in-cluster/06-store-admission-tls.sh`
**Action:** DELETE (removing vault-in-cluster)

#### 3. `security/tls-certificates/cert-manager/validate-certificates.sh`
**Action:** Convert to manual steps in README

**Example Conversion:**
```markdown
## Verify Certificates

### Step 1: Check Certificate Status
kubectl get certificate -n redis

### Step 2: Describe Certificate
kubectl describe certificate rec-tls -n redis

### Step 3: Verify Secret Created
kubectl get secret rec-tls-cert -n redis

### Step 4: Inspect Certificate Details
kubectl get secret rec-tls-cert -n redis -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

---

## 📋 Phase 2: Simplification (Priority 2)

### Task 2.1: Remove Incomplete/Unused Platforms
**Estimated Time:** 30 minutes

**Platforms to Remove:**
- [ ] `platforms/vanilla/` - Too generic, no real value
- [ ] `platforms/aks/` - Incomplete, not tested
- [ ] `platforms/gke/` - Incomplete, not tested

**Platforms to Keep:**
- ✅ `platforms/eks/` - Complete, tested, commonly used
- ✅ `platforms/openshift/` - Complete, well-documented, gold standard

**Commands:**
```bash
rm -rf platforms/vanilla/
rm -rf platforms/aks/
rm -rf platforms/gke/
```

**Update README.md:**
- Remove references to vanilla, AKS, GKE
- Keep only EKS and OpenShift in platform table

---

### Task 2.2: Review Deployment Patterns
**Estimated Time:** 1 hour

**Question to Answer:** Is `deployments/multi-namespace/` commonly used?

**If YES:** Keep it, but simplify documentation
**If NO:** Remove it

**Action:**
```bash
# If removing:
rm -rf deployments/multi-namespace/

# Update README.md to remove multi-namespace references
```

**Deployments to Keep:**
- ✅ `single-region/` - Most common
- ✅ `active-active/` - Enterprise use case
- ✅ `redis-on-flash/` - Cost optimization
- ✅ `rdi/` - Growing use case
- ✅ `redisinsight/` - Useful tool

---

### Task 2.3: Clean Up Root Directory
**Estimated Time:** 15 minutes

**Files to Remove:**
- [ ] `GKE-REVIEW-CHECKLIST.md` - Specific to one engagement
- [ ] `CONTRIBUTING.md` - Not needed for reference repo (or simplify to 10 lines)

**Commands:**
```bash
rm GKE-REVIEW-CHECKLIST.md
# Either remove or drastically simplify CONTRIBUTING.md
```

---

### Task 2.4: Review Security Section
**Estimated Time:** 30 minutes

**Question:** Is `security/ldap-ad-integration/` commonly used?

**If YES:** Keep in main security/
**If NO:** Move to `security/advanced/ldap-ad-integration/`

**Rationale:** LDAP is a niche use case, adds complexity to main security section

**Action:**
```bash
# If moving to advanced:
mkdir -p security/advanced/
mv security/ldap-ad-integration/ security/advanced/

# Update security/README.md to mention advanced section
```

---

## 📋 Phase 3: Polish (Priority 3)

### Task 3.1: Standardize All READMEs
**Estimated Time:** 3-4 hours

**Template to Follow:**
```markdown
# [Component Name]

Brief description (1-2 sentences).

## Prerequisites
- Requirement 1
- Requirement 2

## Architecture (Optional)
[Diagram or description]

## Step-by-Step Deployment

### Step 1: [Action]
```bash
command
```

**Expected output:**
```
output
```

### Step 2: [Next Action]
...

## Verification
How to verify it's working

## Troubleshooting
Common issues and solutions

## Cleanup (Optional)
How to remove
```

**Files to Standardize:**
- [ ] All README.md files in `deployments/`
- [ ] All README.md files in `security/`
- [ ] All README.md files in `integrations/`
- [ ] All README.md files in `networking/`
- [ ] All README.md files in `monitoring/`

---

### Task 3.2: Review YAML Comments
**Estimated Time:** 2 hours

**Standards:**
- All comments in English
- Explain WHY, not just WHAT
- Keep comments concise

**Example:**
```yaml
# BAD:
replicas: 3  # Number of replicas

# GOOD:
replicas: 3  # Minimum for quorum and high availability
```

**Files to Review:**
- [ ] All `.yaml` files in `deployments/`
- [ ] All `.yaml` files in `security/`
- [ ] All `.yaml` files in `integrations/`

---

### Task 3.3: Add Quick Reference Sections
**Estimated Time:** 2 hours

**Create Quick Reference Guides:**

#### 1. `quick-reference/common-commands.md`
```markdown
# Common Commands Quick Reference

## REC Management
kubectl get rec -n redis
kubectl describe rec rec -n redis

## Database Management
kubectl get redb -n redis
kubectl describe redb redis-db -n redis

## Troubleshooting
kubectl logs -n redis rec-0
kubectl exec -it rec-0 -n redis -- bash
```

#### 2. `quick-reference/troubleshooting-checklist.md`
One-page checklist for common issues

#### 3. `quick-reference/architecture-patterns.md`
Visual diagrams of common deployment patterns

---

## 📊 Progress Tracking

### Phase 1: Critical Fixes
- [ ] Task 1.1: Translate Vault to English
- [ ] Task 1.2: Remove vault-in-cluster
- [ ] Task 1.3: Convert scripts to manual steps

### Phase 2: Simplification
- [ ] Task 2.1: Remove unused platforms
- [ ] Task 2.2: Review deployment patterns
- [ ] Task 2.3: Clean up root directory
- [ ] Task 2.4: Review security section

### Phase 3: Polish
- [ ] Task 3.1: Standardize READMEs
- [ ] Task 3.2: Review YAML comments
- [ ] Task 3.3: Add quick reference sections

---

## 🎯 Success Criteria

After completion:
- ✅ 100% English content
- ✅ Zero automation scripts
- ✅ All steps are manual and clear
- ✅ Can be used during client calls
- ✅ Easy to follow for labs
- ✅ Professional and maintainable

---

## ⏱️ Total Estimated Time

- **Phase 1:** 4.5 hours
- **Phase 2:** 2.25 hours
- **Phase 3:** 7 hours
- **Total:** ~14 hours (2 working days)

---

## 🚀 Getting Started

**Recommended Order:**
1. Start with Task 1.2 (Remove vault-in-cluster) - Quick win
2. Then Task 1.1 (Translate Vault) - Most visible
3. Then Task 2.1 (Remove platforms) - Another quick win
4. Continue with remaining tasks

**Questions Before Starting:**
1. Should we keep multi-namespace deployment?
2. Should we move LDAP to advanced section?
3. Any other sections to remove/simplify?

---

**Ready to start? Let's begin with Phase 1!**

