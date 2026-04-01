# MTA Reusable CI/CD Workflows

Reusable GitHub Actions workflows for MTA monorepo CI/CD pipelines.

## Workflows

### 1. CI Change Detection (`ci-change-detection-reusable.yml`)

Detects changed services in monorepo and generates version tags.

**Outputs:**
- `services` - JSON array of changed service paths
- `service_count` - Number of changed services
- `version_tag` - Generated version tag (for staging/hotfix)
- `environment` - Detected environment (development/staging/production)

**Usage:**
```yaml
jobs:
  detect:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@main
```

### 2. CI (`ci-reusable.yml`)

Test, security scan, build, and publish Docker images.

**Inputs:**
- `service_path` - Service path (e.g., `services/my-service`)
- `environment` - Environment (development/staging/production)
- `version_tag` - Version tag for release (optional)

**Outputs:**
- `image_tag` - Docker image tag that was pushed
- `container_scan_passed` - Container security scan result

**Features:**
- Auto-detects service type (Java/Node.js/Python)
- Runs unit tests (parallel with security scan)
- SAST scan (Trivy)
- Dependency scan (Trivy)
- Builds and pushes Docker image to GHCR
- Container security scan
- Docker layer caching for faster builds

**Usage:**
```yaml
jobs:
  build:
    needs: detect
    uses: mta-tech/reusable-workflows/.github/workflows/ci-reusable.yml@main
    strategy:
      matrix:
        service_path: ${{ fromJson(needs.detect.outputs.services) }}
    with:
      service_path: ${{ matrix.service_path }}
      environment: ${{ needs.detect.outputs.environment }}
      version_tag: ${{ needs.detect.outputs.version_tag }}
```

### 3. CD GitOps (`cd-gitops-reusable.yml`)

Deploys via GitOps by updating Helm values in separate repository.

**Inputs:**
- `service_path` - Service path
- `environment` - Environment to deploy
- `version_tag` - Version tag (optional)
- `image_tag` - Docker image tag (optional)

**Secrets:**
- `gitops_repo` - GitOps repository URL
- `gitops_token` - GitHub token for GitOps access

**Usage:**
```yaml
jobs:
  deploy:
    uses: mta-tech/reusable-workflows/.github/workflows/cd-gitops-reusable.yml@main
    with:
      service_path: services/my-service
      environment: staging
      version_tag: v1.0.0
    secrets:
      gitops_repo: mta-tech/gitops-repo
      gitops_token: ${{ secrets.GITOPS_TOKEN }}
```

### 4. Notification (`notification-reusable.yml`)

Sends notifications to Discord/Slack.

**Inputs:**
- `status` - Notification status (success/failure/start)
- `environment` - Environment
- `service_name` - Service name
- `version_tag` - Version tag
- `workflow_name` - Workflow name
- `run_url` - GitHub Actions run URL

**Secrets:**
- `discord_webhook` - Discord webhook URL (optional)
- `slack_webhook` - Slack webhook URL (optional)

## Supported Service Types

| Type | Detected By | Build Tool |
|------|-------------|------------|
| Java | `pom.xml` | Maven |
| Node.js | `package.json` | npm/yarn/pnpm |
| Python | `pyproject.toml` or `requirements.txt` | uv/pip |

## Environment Detection

| Branch Pattern | Environment | Version Tag |
|----------------|-------------|-------------|
| `feat/**` | development | `latest` |
| `release/**` | staging | Branch name (e.g., `v26.3.0`) |
| `hotfix/**` | production | Incremental (e.g., `v1.7.9-hotfix-1`) |

## Docker Registry

All images are pushed to `ghcr.io` (GitHub Container Registry).

Image format: `ghcr.io/{org}/{service-name}:{tag}`

## Required Secrets

Set these in your caller repository:

| Secret | Description |
|--------|-------------|
| `GITOPS_REPO` | GitOps repository (e.g., `mta-tech/gitops-repo`) |
| `GITOPS_TOKEN` | GitHub token with repo access |
| `DISCORD_WEBHOOK` | Discord webhook URL (optional) |
| `SLACK_WEBHOOK` | Slack webhook URL (optional) |

## License

MIT
