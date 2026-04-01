# Reusable Workflows Deployment Plan

## Overview
Deploy reusable workflows ke `mta-tech/reusable-workflows` dan update `test-pipeline` untuk menggunakan GitHub-hosted runners.

## Current State

### Infrastructure
- **Self-hosted GKE runners**: Scale ke 0 (non-aktif)
- **GitHub-hosted runners**: ✅ **SUDAH ADA** (tinggal dipanggil)
- **Reusable workflows**: Belum ada sebagai repo terpisah

### Current Issues
1. ✅ Reusable workflows dari beda repo: **SUDAH SUPPORTED** (dengan GitHub-hosted runners)
2. ✅ Self-hosted runners: **SUDAH SCALE 0** (non-aktif)
3. workflows saat ini pakai inline change detection (akan kembali ke reusable)

## Target State

```
mta-tech organization
├── GitHub-hosted runners (Default group)
│   ├── 2x Large (4-core, 16GB RAM)
│   ├── Auto-scale: 2-10 runners
│   └── Labels: ubuntu-latest, self-hosted (compatibility)
│
├── mta-tech/reusable-workflows (NEW repo)
│   ├── ci-change-detection-reusable.yml
│   ├── ci-build-reusable.yml
│   ├── ci-deploy-gitops-reusable.yml
│   └── ci-notification-reusable.yml
│
└── test-pipeline (caller repo)
    ├── dev-ci.yaml → calls mta-tech/reusable-workflows
    ├── staging-ci.yaml → calls mta-tech/reusable-workflows
    ├── hotfix-prod-ci.yaml → calls mta-tech/reusable-workflows
    └── All CD workflows → calls mta-tech/reusable-workflows
```

## Implementation Plan

### Phase 1: Deploy Reusable Workflows (Day 1)

#### 2.1 Create mta-tech/reusable-workflows Repo

```bash
cd /home/wprayudi/project/mta/reusable-workflows
git init
git add .
git commit -m "Initial commit: Reusable CI/CD workflows"
gh repo create mta-tech/reusable-workflows --public --source .
```

#### 2.2 File Structure
```
.github/workflows/
├── ci-change-detection-reusable.yml
├── ci-build-reusable.yml
├── ci-deploy-gitops-reusable.yml
└── ci-notification-reusable.yml
```

#### 2.3 Key Features

**ci-change-detection-reusable.yml**
- Detect changed services in monorepo
- Auto-detect environment (dev/staging/prod)
- Generate version tags for releases
- Supports shared files detection
- Configurable service roots

**ci-build-reusable.yml**
- Multi-language support (Java, Node.js, Python)
- Auto-detect service type
- Build and push Docker images
- Support build args and security scan

**ci-deploy-gitops-reusable.yml**
- Deploy via GitOps (update Helm values)
- Download artifacts from CI workflow
- Update Chart.yaml and values.yaml

**ci-notification-reusable.yml**
- Send notifications to Discord/Slack
- Support rich formatting with embeds
- Configurable by environment

### Phase 2: Update test-pipeline Workflows (Day 2)

#### 3.1 Update Runner Labels

**SEBELUM:**
```yaml
runs-on: [self-hosted, Linux, X64]
```

**SESUDAH:**
```yaml
runs-on: ubuntu-latest
```

#### 3.2 Update Reusable Workflow References

**SEBELUM:**
```yaml
uses: ./.github/workflows/ci-change-detection-reusable.yml
```

**SESUDAH:**
```yaml
uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@main
```

#### 3.3 Workflows to Update

| Workflow | Changes |
|----------|---------|
| **dev-ci.yaml** | Use ubuntu-latest + external reusable |
| **staging-ci.yaml** | Use ubuntu-latest + external reusable + version tagging |
| **hotfix-prod-ci.yaml** | Use ubuntu-latest + external reusable + hotfix versioning |
| **dev-cd.yaml** | Use ubuntu-latest + external reusable |
| **staging-cd.yaml** | Use ubuntu-latest + external reusable |
| **hotfix-prod-cd.yaml** | Use ubuntu-latest + external reusable |

### Phase 3: Testing (Day 2-3)

#### 4.1 Test Matrix Dynamic Matrix

```yaml
# Test workflow to verify matrix works with external reusable
name: Test Matrix with External Reusable

on: push
jobs:
  detect:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@main
    with:
      environment: development

  build:
    needs: detect
    uses: mta-tech/reusable-workflows/.github/workflows/ci-build-reusable.yml@main
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect.outputs.services) }}
```

#### 4.2 Test Checklist
- [ ] Dev CI/CD berjalan
- [ ] Staging CI/CD berjalan
- [ ] Hotfix Production CI/CD berjalan
- [ ] Matrix builds berjalan
- [ ] Version tagging works
- [ ] Notifications work

### Phase 4: Cutover (Day 3)

#### 5.1 Verify All Systems
```bash
# GitHub-hosted runners active
gh api /orgs/mta-tech/actions/runners

# Workflows running
gh run list --repo mta-tech/test-pipeline --limit 5

# Usage within quota
# Visit: https://github.com/organizations/mta-tech/settings/billing
```

#### 5.2 Clean Up
```bash
# Scale down GKE runners (already at 0)
kubectl scale deployment github-runner -n github-runners --replicas=0

# Verify no self-hosted runners active
gh api /orgs/mta-tech/actions/runners
```

## File Changes Required

### mta-tech/reusable-workflows
```
.github/workflows/
├── ci-change-detection-reusable.yml (inline change detection)
├── ci-build-reusable.yml (build & push images)
├── ci-deploy-gitops-reusable.yml (GitOps deployment)
├── ci-notification-reusable.yml (Discord/Slack notifications)
├── README.md (documentation)
└── LICENSE (MIT)
```

### test-pipeline
```
.github/workflows/
├── dev-ci.yaml
├── dev-cd.yaml
├── staging-ci.yaml
├── staging-cd.yaml
├── hotfix-prod-ci.yaml
├── hotfix-prod-cd.yaml
├── ci-prod-claim-mind-web.yaml
└── ci-prod-claim-mind-developer-portal-web.yaml
```

All workflows updated to:
1. Use `runs-on: ubuntu-latest`
2. Call external reusable workflows
3. Remove inline change detection (back to reusable)

## Rollback Plan

If issues arise:
1. **Revert to inline workflows**: Use current workflows (inline change detection)
2. **Scale up GKE runners**: `kubectl scale deployment github-runner -n github-runners --replicas=4`
3. **Update runner labels**: Revert `runs-on: [self-hosted, Linux, X64]`

## Success Criteria

- [x] GitHub-hosted runners active and healthy (✅ SUDAH ADA)
- [ ] All workflows use `ubuntu-latest`
- [ ] All workflows call external reusable workflows
- [ ] Matrix builds working with external reusable
- [x] GKE runners scaled to 0
- [ ] All CI/CD pipelines functional
- [ ] Usage within 50,000 menit/month quota

## Next Steps

1. **Deploy reusable-workflows** ke mta-tech/reusable-workflows (sebagai public repo)
2. **Update test-pipeline** workflows untuk menggunakan external reusable workflows
3. **Test** thoroughly dengan GitHub-hosted runners
4. **Verify** CI/CD pipelines functional

## References

- [GitHub Actions: Workflow reuse](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Actions: Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [GitHub Actions: Runner groups](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-actions/runner-groups)

---

**Created:** 2026-04-01
**Last Updated:** 2026-04-01
**Status:** Draft - Ready for Review
