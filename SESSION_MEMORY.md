# Session Memory

## Purpose

Quick reference for the current reusable workflow and `test-pipeline` migration state.
Read this file first in the next session before continuing work.

## Repositories

- Reusable workflows repo:
  - `/home/wprayudi/project/mta/reusable-workflows`
- Consumer repo:
  - `/home/wprayudi/project/mta/test-pipeline`

## Current Workflow Model

`test-pipeline` now uses reusable workflows from `mta-tech/reusable-workflows`:

- `ci-change-detection-reusable.yml`
- `ci-build-reusable.yml`
- `cd-gitops-reusable.yml`
- `cd-cloudrun-reusable.yml`
- `notify-reusable.yml`

Caller workflows in `test-pipeline`:

- `dev-pipeline.yaml`
- `staging-pipeline.yaml`
- `hotfix-prod-pipeline.yaml`
- `release-prod-pipeline.yaml`
- `staging-rollback-pipeline.yaml`

## Current Tagging Rules

- Dev image tag:
  - `dev-<git_sha>`
- Staging:
  - follows branch name, for example `release/v26.3.0` -> `v26.3.0`
- Production release:
  - run from git tag, for example `v26.3.0`
- Production hotfix:
  - `v26.3.0-hotfix-1`, `v26.3.0-hotfix-2`, and so on

## Important Implementation Decisions

- Production normal release:
  - backend is promoted by release tag
  - frontend is rebuilt with production env before deploy
- Hotfix production:
  - frontend is rebuilt with production env
  - hotfix tag uses incrementing suffix, not timestamp
- Staging rollback:
  - updates only `image.tag`
  - does not overwrite `image.repository`
  - does not update `Chart.yaml`
- Unknown changed services in monorepo:
  - may still build
  - only mapped services deploy

## Reusable Workflow Improvements Already Applied

### `ci-build-reusable.yml`

Added feature flags:

- `enable_test`
- `enable_security_scan`
- `enable_filesystem_scan`
- `enable_image_scan`
- `upload_security_artifacts`
- `upload_build_metadata`
- `enable_summary`

Added frontend env file support:

- `env_file_path`
- `env_file_content`
- `env_file_var_name`

### `cd-gitops-reusable.yml`

Added feature flags:

- `update_image_tag`
- `update_image_repository`
- `update_chart_version`
- `commit_changes`
- `enable_summary`

Added:

- `commit_message`

### `cd-cloudrun-reusable.yml`

Added:

- `enable_summary`

### `notify-reusable.yml`

Added:

- `enable_discord`
- `enable_slack`

## Caller Cleanup Already Applied In `test-pipeline`

- removed repeated default inputs like `push_image: true`
- removed repeated default inputs like `enable_security_scan: true`
- replaced long inline frontend `.env` blocks with `env_file_var_name`

## Pending Work

Frontend env source strategy is now:

- keep caller workflows compact
- store FE `.env` payloads as environment-scoped GitHub secrets
- reusable build workflow materializes `.env` at runtime

Current caller files expect these environment secrets:

- `CLAIM_MIND_WEB_STAGING_ENV_FILE`
- `CLAIM_MIND_PORTAL_STAGING_ENV_FILE`
- `CLAIM_MIND_WEB_PROD_ENV_FILE`
- `CLAIM_MIND_PORTAL_PROD_ENV_FILE`

Current implementation details:

- reusable build workflow supports `env_file_secret_name`
- reusable build `test` and `build` jobs set `environment: ${{ inputs.environment }}`
- staging FE caller uses `env_file_secret_name`
- hotfix prod FE caller uses `env_file_secret_name`
- release prod FE caller uses `env_file_secret_name`
- caller build jobs in `test-pipeline` currently set `enable_test: false`
- Trivy filesystem and image scans remain enabled
- `apps/claim-mind-desktop` is explicitly skipped in `dev`, `staging`, and `hotfix` caller `prepare` jobs so it does not enter build or deploy matrices
- Trivy scan results are now summarized in GitHub Step Summary and uploaded as artifacts:
  - `trivy-fs-<service_name>`
  - `trivy-image-<service_name>`
- Trivy action was pinned from `@master` to `@v0.33.1`
- repo now has contract docs under `docs/contracts/` for:
  - `ci-change-detection-reusable.yml`
  - `ci-build-reusable.yml`
  - `cd-gitops-reusable.yml`
  - `cd-cloudrun-reusable.yml`
  - `notify-reusable.yml`

## Validation Status

- reusable workflow YAML passed `actionlint`
- caller workflow YAML in `test-pipeline` passed `actionlint`
- `git diff --check` passed for both repos after latest edits

## Remaining Platform Work

- decide and publish release strategy for `@v1`
- review third-party actions and pin them to full commit SHA where appropriate
- confirm minimum permissions are sufficient across all workflows
- optionally update `test-pipeline` callers from pilot state to final external `@v1` consumption once tag is published

## Recommended Next Prompt

Use something like:

`Baca SESSION_MEMORY.md lalu lanjutkan dari pending work terakhir`
