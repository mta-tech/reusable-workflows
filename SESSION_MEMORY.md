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
- reusable build workflow now supports caller-level policy toggles:
  - `fail_on_filesystem_findings`
  - `fail_on_image_findings`
- `test-pipeline` callers currently set both Trivy fail-policy toggles to `false` so scans still run, summaries and artifacts still publish, but findings do not fail the build during rollout
- `apps/claim-mind-desktop` is explicitly skipped in `dev`, `staging`, and `hotfix` caller `prepare` jobs so it does not enter build or deploy matrices
- Trivy scan results are now summarized in GitHub Step Summary and uploaded as artifacts:
  - `trivy-fs-<service_name>`
  - `trivy-image-<service_name>`
- Trivy scanning now uses:
  - official container image `aquasec/trivy:0.65.0`
  - registry auth for image scan comes from `gcloud auth print-access-token`
  - direct `trivy fs` and `trivy image` CLI execution
- this replaced the previous `trivy-action` wrapper because the wrapper path was failing during setup on GitHub runners
- repo now has contract docs under `docs/contracts/` for:
  - `ci-change-detection-reusable.yml`
  - `ci-build-reusable.yml`
  - `cd-gitops-reusable.yml`
  - `cd-cloudrun-reusable.yml`
  - `notify-reusable.yml`

## Validation Status

- reusable workflow YAML passed `actionlint`
- caller workflow YAML in `test-pipeline` passed `actionlint`
- reusable workflow release `v1.0.14` is published and `v1` points to commit `47e9723`
- fresh staging validation run `23994062314` in `mta-tech/test-pipeline` completed `success`
- that success run was triggered by an empty commit (`7969a37`) on `release/v26.3.0`, so it validated reusable resolution, detect, and notify with the latest `@v1`
- build and deploy jobs were skipped in `23994062314` because no service changed in the empty commit; a real service change is still needed for full end-to-end build/deploy verification
- focused dev validation run `23994844117` proved Trivy runtime/auth is fixed:
  - filesystem scan succeeded
  - image scan succeeded
  - the workflow failed only because strict image scan policy blocked on real `HIGH/CRITICAL` findings
- current rollout decision:
  - keep Trivy scans running
  - keep Trivy summaries and artifacts enabled
  - disable fail-on-findings in `test-pipeline` callers temporarily to avoid blocking rollout and wasting runner minutes on repeated red runs
- `test-pipeline` branch `feat/cicd` now includes commit `f52f0bb` (`chore(actions): make trivy findings non-blocking`)
- validation run `23995037573` was intentionally cancelled after detect/prepare because the workflow-file-only change fanned out to many services via `.github` shared paths and would waste runner minutes
- focused single-service validation commit on `feat/cicd`:
  - `ba95e90` (`chore(actions): validate app-api-gateway single-service pipeline`)
- focused run `23996119217` proved the following for `services/app-api-gateway` in `Development Pipeline`:
  - detect succeeded
  - prepare succeeded
  - metadata, filesystem scan, build/push image, and Trivy image scan all succeeded
  - filesystem/image enforce steps were skipped as intended by the non-blocking rollout toggles
  - deploy target routing was correct: GitOps deploy started, Cloud Run deploy was skipped
- current end-to-end blocker:
  - `deploy_gitops` failed at `Checkout GitOps repository`
  - error: `fatal: could not read Username for 'https://github.com': terminal prompts disabled`
  - reusable `cd-gitops-reusable.yml` used `repository: mta-tech/gitops-platform` with `secrets.gitops_token`
  - this indicates GitOps repository checkout auth is still not valid for `mta-tech/gitops-platform` from `test-pipeline`
- org-level `GH_PAT` may still be present even when `gh secret list --repo mta-tech/test-pipeline` shows no repo secrets
- latest UX changes requested by user:
  - dev image tags in `test-pipeline` should use `latest`
  - Trivy summaries should show severity table plus top critical/high findings in GitHub Step Summary, similar to legacy CI screenshots
- image naming contract was updated to support an application namespace between the Docker repo and service:
  - reusable `ci-build-reusable.yml` now accepts optional input `application`
  - default image path becomes `<registry>/<project>/<docker_repo>/<application>/<service>:<tag>` when `application` is set
  - `service_name` remains auto-derived from `service_path`
  - `test-pipeline` callers now use `application: claimmind`
  - dev example path: `asia-southeast2-docker.pkg.dev/mta-dev-app-os/mta-docker/claimmind/app-api-gateway:latest`
  - staging example path: `asia-southeast2-docker.pkg.dev/<staging-project>/<repo>/claimmind/<service>:vX.Y.Z`
  - production and hotfix now use the same `claimmind/<service>` pattern for both backend and FE, replacing the older FE-specific repository overrides
- Discord notification payload in `notify-reusable.yml` is being upgraded from plain text to a richer embed with:
  - status
  - environment
  - service
  - version
  - repository
  - branch
  - actor
  - short commit
  - workflow run link
- `git diff --check` passed for both repos after latest edits

## Remaining Platform Work

- decide and publish release strategy for `@v1`
- review third-party actions and pin them to full commit SHA where appropriate
- confirm minimum permissions are sufficient across all workflows
- optionally update `test-pipeline` callers from pilot state to final external `@v1` consumption once tag is published

## Latest Notes

- `gitops-platform` rollout annotation support is now in place for staging on:
  - `app-api-gateway`
  - `cl-service`
  - `claim-mind-agent-router`
  - `claim-mind-developer-portal-web`
  - `claim-mind-vector-db-service`
  - `claim-mind-web`
  - `cm-cube-open-api-service`
  - `cm-cube-service`
  - `cm-open-api-service`
  - `ocr-vnext`
  - `open-api-gateway`
- latest pushed infra commits before this note:
  - `gitops-platform` `main`: `7f44a9d`
  - `reusable-workflows` `main`: `b8b51d5`
  - reusable tag: `v1.0.21`
- `test-pipeline` branch `release/v26.3.0` already includes staging rollout annotation enablement via commit `abe94b4`
- as of this session, `cm-cube-open-api-service` and `cm-cube-service` were added to caller GitOps CD mappings in:
  - `staging-pipeline.yaml`
  - `hotfix-prod-pipeline.yaml`
  - `release-prod-pipeline.yaml`
- the new caller mapping expects these repo/org variables to exist in `test-pipeline`:
  - `GITOPS_VALUES_FILE_PATH_CM_CUBE_OPEN_API_SERVICE`
  - `GITOPS_VALUES_FILE_PATH_CM_CUBE_SERVICE`
- org-level notification credentials confirmed by user:
  - variable: `SLACK_CHANNEL_ID`
  - secrets: `DISCORD_WEBHOOK`, `SLACK_BOT_TOKEN`, `SLACK_WEBHOOK_URL`
- `notify-reusable.yml` was adjusted to use org-standard secret names:
  - `DISCORD_WEBHOOK`
  - `SLACK_WEBHOOK_URL`
  - `SLACK_BOT_TOKEN`
- current Slack delivery in reusable still uses incoming webhook payloads
  - this was upgraded in a later session to prefer `SLACK_BOT_TOKEN + SLACK_CHANNEL_ID` with Slack Block Kit formatting inspired by the legacy pipeline under `/home/wprayudi/project/mta/backup/.github/workflows`
  - if bot token or channel id is unavailable, reusable notifier still falls back to `SLACK_WEBHOOK_URL`
- reusable notifier was further upgraded to build a run-aware summary directly from GitHub Actions job data:
  - uses `gh run view <run_id> --json jobs`
  - summarizes build/deploy/tag/rollback jobs into a human-friendly `Rangkuman Build`
  - Slack and Discord now render:
    - stronger title/status wording
    - `Tag`
    - `Commit`
    - `Rangkuman Build`
    - workflow run button/link
- startup failure on the first rich-summary rollout was resolved in two parts:
  - reusable fix: `f26965f` then `8691c05`
  - caller fix: add `actions: read` permission so the reusable notifier can read run jobs
- latest reusable notifier release:
  - `reusable-workflows` `main`: `8137919`
  - reusable tag: `v1.0.27`
  - `v1` points to `v1.0.27`
- validation status for the richer notifier:
  - run `24503953942` on `feat/notify-slack-validation` completed with `notify` success
  - successful notify steps:
    - `Prepare payload metadata`
    - `Build notification summary`
    - `Send Discord notification`
    - `Send Slack notification`
- Discord layout was further polished to better match the cleaner Slack style:
  - author/title now link to the workflow run
  - Indonesian labels are used consistently (`Tag`, `Commit`, `Lingkungan`, `Pemicu`, `Rangkuman Build`)
  - key metadata is grouped into cleaner fields instead of a flat/basic embed
  - validation run `24505208948` completed with `notify` success after the Discord layout polish
- the `actions: read` caller permission fix is now also pushed to the operational branch:
  - `test-pipeline` `release/v26.3.0`: `1561e04`
- `cl-service-scheduler` has now been added for GitOps staging and prod:
  - `gitops-platform` `main`: `bc7143a`
  - added:
    - `helm/cl-service-scheduler`
    - `environments/staging/cl-service-scheduler/values.yaml`
    - `environments/prod/cl-service-scheduler/values.yaml`
    - `argocd/staging/apps/cl-service-scheduler.yaml`
    - `argocd/prod/apps/cl-service-scheduler.yaml`
- caller workflow mappings for `cl-service-scheduler` are now pushed to:
  - `test-pipeline` `release/v26.3.0`: `5eec0b2`
  - updated workflows:
    - `staging-pipeline.yaml`
    - `hotfix-prod-pipeline.yaml`
    - `release-prod-pipeline.yaml`
    - `staging-rollback-pipeline.yaml`
- new repo/org variable expected in `test-pipeline`:
  - `GITOPS_VALUES_FILE_PATH_CL_SERVICE_SCHEDULER`

## Recommended Next Prompt

Use something like:

`Baca SESSION_MEMORY.md lalu lanjutkan dari pending work terakhir`
