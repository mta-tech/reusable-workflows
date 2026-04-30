# Reusable Workflows

Reusable GitHub Actions workflows for `mta-tech` repositories.

## Release Usage

Consumer workflows are expected to reference a major tag such as `@v1`.
Create and push that tag before enabling callers in application repositories.

## Available Workflows

### `ci-change-detection-reusable.yml`

Use this in monorepos to detect changed services and produce a JSON matrix.

Outputs:
- `services`
- `service_matrix`
- `service_count`
- `changed`
- `version_tag`
- `environment`

Contract:
- [`docs/contracts/ci-change-detection-reusable.md`](docs/contracts/ci-change-detection-reusable.md)

### `ci-build-reusable.yml`

Use this to test, scan, build, and optionally push a Docker image for one service.

Common feature flags:
- `enable_test`
- `enable_security_scan`
- `enable_filesystem_scan`
- `enable_image_scan`
- `upload_build_metadata`
- `enable_summary`

Cleaner caller option for frontend env files:
- `env_file_var_name`
  Point this to one multiline repo or org variable so the caller does not need to inline long `.env` content.
- `env_file_secret_name`
  Point this to one multiline repository or environment secret when the `.env` contains sensitive values.

Outputs:
- `service_name`
- `image_tag`
- `artifact_name`
- `container_scan_passed`

Contract:
- [`docs/contracts/ci-build-reusable.md`](docs/contracts/ci-build-reusable.md)

Required vars:
- `DOCKER_REGISTRY_HOST`
- `DOCKER_REPO_GLOBAL`
- `DOCKER_PROJECT_ID_DEVELOPMENT`
- `DOCKER_PROJECT_ID_STAGING`
- `DOCKER_PROJECT_ID_PRODUCTION`

Optional secrets when `push_image: true`:
- `gcp_workload_identity_provider`
- `gcp_service_account`

### `cd-gitops-reusable.yml`

Use this to update a GitOps repository with a new image reference.

Common feature flags:
- `update_image_tag`
- `update_image_repository`
- `update_chart_version`
- `commit_changes`
- `enable_summary`

Outputs:
- `deployed_commit`
- `deployed_image_tag`

Required secret:
- `gitops_token`

Contract:
- [`docs/contracts/cd-gitops-reusable.md`](docs/contracts/cd-gitops-reusable.md)

### `cd-cloudrun-reusable.yml`

Use this to deploy a service directly to Google Cloud Run.

Common feature flags:
- `enable_summary`

Outputs:
- `service_url`

Required secrets:
- `gcp_workload_identity_provider`
- `gcp_service_account`

Contract:
- [`docs/contracts/cd-cloudrun-reusable.md`](docs/contracts/cd-cloudrun-reusable.md)

### `promote-image-reusable.yml`

Use this to promote an existing container image from one registry reference to another without rebuilding it.

Common feature flags:
- `enable_summary`

Outputs:
- `promoted_image`

Required secrets:
- `gcp_workload_identity_provider`
- `gcp_service_account`

Contract:
- [`docs/contracts/promote-image-reusable.md`](docs/contracts/promote-image-reusable.md)

### `notify-reusable.yml`

Use this at the end of a pipeline to send Slack or Discord notifications.

Common feature flags:
- `enable_discord`
- `enable_slack`

Optional secrets:
- `slack_webhook`
- `discord_webhook`

Contract:
- [`docs/contracts/notify-reusable.md`](docs/contracts/notify-reusable.md)

## Example: Monorepo Staging Pipeline

```yaml
name: Staging Pipeline

on:
  push:
    branches: [release/**]

jobs:
  detect:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@v1
    with:
      environment: staging
      service_roots: '["apps","services"]'
      shared_paths: '["libs","packages",".github"]'

  build:
    needs: detect
    if: needs.detect.outputs.changed == 'true'
    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJson(needs.detect.outputs.service_matrix) }}
    uses: mta-tech/reusable-workflows/.github/workflows/ci-build-reusable.yml@v1
    with:
      service_path: ${{ matrix.service.service_path }}
      environment: staging
      version_tag: ${{ needs.detect.outputs.version_tag }}
      env_file_secret_name: STAGING_SERVICE_ENV_FILE
    secrets: inherit

  deploy:
    needs:
      - detect
      - build
    if: needs.detect.outputs.changed == 'true'
    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJson(needs.detect.outputs.service_matrix) }}
    uses: mta-tech/reusable-workflows/.github/workflows/cd-gitops-reusable.yml@v1
    with:
      environment: staging
      service_path: ${{ matrix.service.service_path }}
      service_name: ${{ matrix.service.service_name }}
      image_tag: ${{ vars.DOCKER_REGISTRY_HOST }}/${{ vars.DOCKER_PROJECT_ID_STAGING }}/${{ vars.DOCKER_REPO_GLOBAL }}/${{ matrix.service.service_name }}:${{ needs.detect.outputs.version_tag }}
      version_tag: ${{ needs.detect.outputs.version_tag }}
      gitops_repo: mta-tech/gitops-repo
    secrets:
      gitops_token: ${{ secrets.GITOPS_TOKEN }}

  notify:
    needs:
      - detect
      - build
      - deploy
    if: always()
    uses: mta-tech/reusable-workflows/.github/workflows/notify-reusable.yml@v1
    with:
      status: ${{ needs.deploy.result || needs.build.result }}
      environment: staging
      workflow_name: Staging Pipeline
      version_tag: ${{ needs.detect.outputs.version_tag }}
    secrets: inherit
```

## Example: `test-pipeline` Layout

Recommended caller workflows in `test-pipeline`:
- `dev-pipeline.yaml`
- `staging-pipeline.yaml`
- `release-prod-pipeline.yaml`
- `hotfix-prod-pipeline.yaml`

If you want to migrate gradually, keep the current files and replace inline logic with these reusable workflows first:
- `dev-ci.yaml`
- `dev-cd.yaml`
- `staging-ci.yaml`
- `staging-cd.yaml`
- `hotfix-prod-ci.yaml`
- `hotfix-prod-cd.yaml`
