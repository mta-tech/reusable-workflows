# Reusable Workflows Platform Plan

## Overview

Dokumen ini mendefinisikan rencana membangun `mta-tech/reusable-workflows` sebagai platform reusable GitHub Actions yang aman, versioned, dan bisa dipakai lintas repository, baik untuk monorepo maupun single-service repository.

Target utamanya bukan hanya memindahkan workflow dari `test-pipeline`, tetapi membangun workflow contract yang:
- konsisten dipakai banyak repo,
- aman untuk organisasi,
- mudah di-upgrade,
- tidak mengunci implementasi ke satu struktur repo saja.

## Goals

- Menyediakan reusable workflows standar untuk CI, CD GitOps, change detection, dan notification.
- Mendukung caller dari monorepo dan non-monorepo.
- Menstandarkan input, output, permissions, secret contract, dan versioning.
- Menggunakan GitHub-hosted runners sebagai default execution platform.
- Meminimalkan duplikasi workflow di repo aplikasi.
- Menyediakan jalur adopsi bertahap dari workflow inline ke external reusable workflows.

## Non-Goals

- Bukan pengganti seluruh pipeline logic aplikasi. Logic yang sangat spesifik per service tetap berada di caller repo atau custom action.
- Bukan tempat menyimpan secret organisasi.
- Bukan tempat orchestration yang bergantung pada tooling lokal runner self-hosted kecuali memang ada exception yang disetujui.

## Design Principles

1. Reusable by contract
   Workflow harus reusable berdasarkan input dan output yang jelas, bukan bergantung pada nama repo tertentu.

2. Secure by default
   Semua workflow memakai permission minimum, mendukung OIDC, dan menghindari hardcoded credential.

3. Versioned adoption
   Caller wajib memanggil release tag atau major tag seperti `@v1`, bukan `@main`, untuk stabilitas.

4. Monorepo-first, but not monorepo-only
   Workflow harus bisa dipakai oleh repo dengan banyak service maupun repo dengan satu service.

5. Thin caller, smart reusable
   Repo aplikasi cukup mendefinisikan event, policy, dan parameter. Logic CI/CD generik dipindahkan ke repo reusable.

6. Observable and supportable
   Setiap workflow harus menghasilkan output, summary, dan error message yang membantu troubleshooting.

## Current State

### Infrastructure
- Self-hosted GKE runners sudah scale ke 0.
- GitHub-hosted runners sudah tersedia dan menjadi target default.
- Repository reusable workflow sudah disiapkan di workspace ini, namun belum difinalisasi sebagai shared platform lintas repo.

### Existing Reusable Workflows in This Repo
- `.github/workflows/ci-change-detection-reusable.yml`
- `.github/workflows/ci-build-reusable.yml`
- `.github/workflows/cd-gitops-reusable.yml`
- `.github/workflows/notify-reusable.yml`

### Current Gaps
- Naming workflow belum sepenuhnya konsisten dengan target platform contract.
- Belum ada dokumentasi contract yang tegas untuk input, output, secrets, vars, dan permissions.
- Referensi rollout masih fokus ke `test-pipeline`, belum digeneralisasi untuk repo lain.
- Belum ada strategy versioning dan backward compatibility yang jelas.
- Belum ada compatibility matrix untuk monorepo vs single-service repository.

## Target State

```text
mta-tech organization
├── GitHub-hosted runners
│   └── ubuntu-latest sebagai default runner untuk reusable workflows
│
├── mta-tech/reusable-workflows
│   ├── .github/workflows/ci-change-detection-reusable.yml
│   ├── .github/workflows/ci-build-reusable.yml
│   ├── .github/workflows/cd-gitops-reusable.yml
│   ├── .github/workflows/notify-reusable.yml
│   ├── README.md
│   ├── docs/contracts/
│   └── release tags: v1, v1.x.x
│
├── monorepo-a
│   ├── dev-ci.yaml
│   ├── staging-ci.yaml
│   └── hotfix-prod-ci.yaml
│
└── service-repo-b
    ├── ci.yaml
    └── cd.yaml
```

## Platform Architecture

### Workflow Layers

1. Caller workflow
   Menentukan trigger, branch policy, environment policy, concurrency, dan parameter workflow.

2. Reusable workflow
   Menjalankan logic generik seperti change detection, test, build, scan, push image, GitOps update, dan notification.

3. Optional custom action or script
   Dipakai bila ada logic yang terlalu kompleks atau terlalu panjang untuk disimpan langsung di YAML.

### Proposed Standard Workflow Set

#### 1. `ci-change-detection-reusable.yml`
Tujuan:
- mendeteksi service yang berubah,
- mendukung monorepo dan single-service repo,
- menghasilkan matrix output yang bisa langsung dipakai caller.

Output minimum:
- `services`
- `changed`
- `environment`
- `version_tag`

Kemampuan:
- configurable `service_roots`,
- configurable `shared_paths`,
- mode `single-service`,
- optional release tagging convention untuk staging dan production.

#### 2. `ci-build-reusable.yml`
Tujuan:
- menjalankan test,
- melakukan security scan,
- build image,
- push artifact/image bila dibutuhkan.

Output minimum:
- `image_tag`
- `service_name`
- `artifact_name`
- `container_scan_passed`

Kemampuan:
- Java, Node.js, Python detection,
- support Docker build args,
- optional push image,
- optional security scan,
- deterministic tagging.

#### 3. `cd-gitops-reusable.yml`
Tujuan:
- mengupdate GitOps repository secara konsisten dan aman.

Output minimum:
- `deployed_commit`
- `deployed_image_tag`

Kemampuan:
- update `values.yaml` dan `Chart.yaml`,
- environment mapping,
- configurable chart path,
- guardrail untuk branch target dan path yang valid.

#### 4. `notify-reusable.yml`
Tujuan:
- mengirim notifikasi standar lintas workflow.

Kemampuan:
- Slack dan Discord,
- status `start`, `success`, `failure`,
- link ke workflow run,
- metadata service, environment, version, repository.

## Naming and Versioning Strategy

### Naming

Agar jelas dan stabil untuk consumer, target nama file workflow:

```text
.github/workflows/
├── ci-change-detection-reusable.yml
├── ci-build-reusable.yml
├── cd-gitops-reusable.yml
└── notify-reusable.yml
```

Catatan:
- Workflow build utama menggunakan nama `ci-build-reusable.yml`.
- Workflow `cd-gitops-reusable.yml` dipertahankan sebagai workflow CD.
- Workflow notification utama menggunakan nama `notify-reusable.yml`.

### Versioning

Consumer harus memanggil workflow menggunakan tag:

```yaml
uses: mta-tech/reusable-workflows/.github/workflows/ci-build-reusable.yml@v1
```

Aturan:
- Jangan gunakan `@main` untuk production consumers.
- Gunakan semantic versioning untuk release.
- Maintain moving major tag seperti `v1`.
- Breaking change hanya boleh masuk ke `v2`.

## Security Baseline

### Repository Visibility

Default recommendation:
- gunakan `internal` bila semua consumer berada dalam GitHub organization yang sama,
- gunakan `private` bila ada logic sensitif yang tidak perlu diekspos,
- gunakan `public` hanya bila memang ada kebutuhan eksplisit.

Untuk use case saat ini, `internal` lebih aman daripada `public` kecuali ada alasan bisnis yang jelas.

### Authentication and Secrets

- Gunakan OIDC untuk cloud authentication jika memungkinkan.
- Secret sensitif tetap dikelola di repo caller, environment, atau organization secrets.
- Reusable workflow hanya mendeklarasikan secret contract, bukan menyimpan nilainya.
- Hindari PAT bila GitHub App atau `GITHUB_TOKEN` cukup.

### Minimal Permissions

Setiap reusable workflow wajib mendefinisikan `permissions` minimum.

Contoh baseline:

```yaml
permissions:
  contents: read
  id-token: write
```

Tambahkan permission lain hanya jika benar-benar dibutuhkan, misalnya:
- `packages: write` untuk push image ke registry tertentu,
- `pull-requests: write` bila workflow perlu comment ke PR.

### Action Supply Chain

- Pin third-party actions ke full commit SHA untuk workflow produksi.
- Hindari `@master`, `@main`, atau tag floating untuk action pihak ketiga.
- Review dan maintain allowlist action yang diizinkan organisasi.

## Standard Contract for Consumers

### Required Inputs

Setiap reusable workflow harus punya input yang eksplisit, tervalidasi, dan terdokumentasi.

Contoh input generik:
- `environment`
- `service_path`
- `service_name`
- `version_tag`
- `image_tag`
- `push_image`
- `enable_security_scan`

### Output Contract

Output harus stabil dan backward compatible dalam major version yang sama.

Contoh:
- `services` dari change detection harus selalu berupa JSON array.
- `image_tag` dari build harus selalu berupa string final image reference.
- `deployed_commit` dari deploy harus selalu berupa SHA commit GitOps.

### Secret Contract

Dokumentasikan secret per workflow secara eksplisit.

## CI and CD Responsibilities in `test-pipeline`

Bagian ini menjelaskan alur caller workflow di `test-pipeline` setelah migrasi ke reusable workflows, khususnya pembagian mana yang termasuk CI dan mana yang termasuk CD.

### CI Responsibilities

CI di `test-pipeline` bertanggung jawab untuk:
- mendeteksi service yang berubah,
- menentukan `environment` dan `version_tag`,
- menyiapkan matrix build dan deploy,
- menjalankan test,
- menjalankan security scan,
- build image Docker,
- push image ke registry.

Reusable workflows yang menjalankan fungsi CI:
- `ci-change-detection-reusable.yml`
- `ci-build-reusable.yml`

### CD Responsibilities

CD di `test-pipeline` bertanggung jawab untuk:
- mengupdate manifest GitOps,
- deploy image ke Cloud Run,
- membuat git tag release atau hotfix bila diperlukan,
- mengirim notifikasi hasil pipeline.

Reusable workflows yang menjalankan fungsi CD:
- `cd-gitops-reusable.yml`
- `cd-cloudrun-reusable.yml`
- `notify-reusable.yml`

### CI vs CD by Caller Workflow

| Caller workflow | Trigger | CI responsibilities | CD responsibilities |
| --- | --- | --- | --- |
| `dev-pipeline.yaml` | `push` ke `feat/**` | detect changed services, prepare matrix, build changed services, test, scan, push image `dev-<sha>` | deploy ke GitOps development untuk service yang mapped, deploy ke Cloud Run development untuk service yang mapped, notify |
| `staging-pipeline.yaml` | `push` ke `release/**` | detect changed services, derive release tag dari branch, prepare matrix, build standard service, build FE dengan env staging, test, scan, push image release | deploy ke GitOps staging, deploy ke Cloud Run staging, create git tag release bila belum ada, notify |
| `hotfix-prod-pipeline.yaml` | `push` ke `hotfix/**` | detect changed services, generate hotfix tag `vX.Y.Z-hotfix-N`, prepare matrix, build standard service, build FE dengan env prod, test, scan, push image hotfix | deploy ke GitOps production, deploy ke Cloud Run production, create git tag hotfix, notify |
| `release-prod-pipeline.yaml` | `workflow_dispatch` dari git tag | prepare selected service target, optional FE prod rebuild bila FE dipilih, push image bila FE dibuild ulang | deploy ke GitOps production, deploy ke Cloud Run production, notify |
| `staging-rollback-pipeline.yaml` | `workflow_dispatch` | tidak ada CI build/test; hanya prepare metadata rollback | update GitOps ke tag rollback yang dipilih, notify |

### Current Runtime Flow

#### Development

```text
push feat/*
-> detect
-> prepare
-> build changed services
-> deploy GitOps dev for mapped services
-> deploy Cloud Run dev for mapped services
-> notify
```

#### Staging

```text
push release/vX.Y.Z
-> detect
-> prepare
-> build standard services
-> build claim-mind-web with staging env
-> build claim-mind-developer-portal-web with staging env
-> deploy GitOps staging
-> deploy Cloud Run staging
-> tag release
-> notify
```

#### Hotfix Production

```text
push hotfix/vX.Y.Z
-> detect
-> prepare
-> build standard services
-> build FE with production env
-> deploy GitOps production
-> deploy Cloud Run production
-> tag hotfix
-> notify
```

#### Release Production

```text
manual run from git tag
-> prepare selected service
-> optional FE production rebuild
-> deploy GitOps production
-> deploy Cloud Run production
-> notify
```

#### Staging Rollback

```text
manual rollback
-> prepare rollback target
-> update GitOps values to target tag
-> notify
```

### Mapping Logic in `prepare`

Job `prepare` pada caller workflow bertugas mengubah output `detect` menjadi matrix operasional:
- `build_matrix` atau `standard_build_matrix`
- `gitops_matrix`
- `cloudrun_matrix`
- flag FE seperti `web_required` dan `portal_required`

Artinya:
- CI tidak langsung deploy semua service yang berubah,
- caller workflow terlebih dahulu menentukan service mana yang memang punya target deploy GitOps,
- caller workflow juga menentukan service mana yang harus deploy ke Cloud Run,
- FE dipisahkan dari backend karena membutuhkan build-time environment yang berbeda.

Contoh:
- `gcp_workload_identity_provider`
- `gcp_service_account`
- `gitops_token`
- `slack_webhook`
- `discord_webhook`

### Variable Contract

Dokumentasikan juga org/repo vars yang wajib tersedia.

Contoh:
- `DOCKER_REGISTRY_HOST`
- `DOCKER_REPO_GLOBAL`
- `DOCKER_PROJECT_ID_DEVELOPMENT`
- `DOCKER_PROJECT_ID_STAGING`
- `DOCKER_PROJECT_ID_PRODUCTION`

## Monorepo and Single-Service Compatibility

### Monorepo Mode

Pattern:
- caller memanggil change detection,
- output `services` dipakai untuk dynamic matrix,
- tiap service dibuild/deploy secara independen.

Contoh:

```yaml
jobs:
  detect:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@v1
    with:
      environment: development
      service_roots: '["services","apps"]'
      shared_paths: '["libs","packages",".github"]'

  build:
    needs: detect
    if: needs.detect.outputs.changed == 'true'
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect.outputs.services) }}
    uses: mta-tech/reusable-workflows/.github/workflows/ci-build-reusable.yml@v1
    with:
      service_path: ${{ matrix.service }}
      environment: development
```

### Single-Service Mode

Pattern:
- caller tidak perlu dynamic matrix,
- service path bisa fixed atau root project.

Contoh:

```yaml
jobs:
  build:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-build-reusable.yml@v1
    with:
      service_path: .
      environment: development
```

## Rollout Strategy

### Phase 1: Foundation Hardening

Tujuan:
- merapikan naming,
- memastikan workflow contract stabil,
- menambah dokumentasi,
- memastikan security baseline.

Checklist:
- [ ] Rename workflow file ke naming target platform.
- [ ] Tambahkan `README.md` dengan contoh caller workflow.
- [ ] Tambahkan dokumentasi contract untuk inputs, outputs, secrets, vars, dan permissions.
- [ ] Tambahkan release strategy `v1`.
- [ ] Review semua third-party actions dan pin ke SHA.
- [ ] Tambahkan `permissions` minimum pada semua workflow.

### Phase 2: Platform Publish

Tujuan:
- publish repo agar bisa dikonsumsi lintas repo dalam organisasi.

Langkah:

```bash
cd /home/wprayudi/project/mta/reusable-workflows
git add .
git commit -m "feat: prepare reusable workflows platform v1"
gh repo create mta-tech/reusable-workflows --internal --source .
```

Catatan:
- Jika repo sudah ada, skip inisialisasi baru dan gunakan remote yang existing.
- Visibility `internal` adalah default recommendation.

### Phase 3: Consumer Pilot

Target awal:
- `test-pipeline` sebagai pilot consumer,
- minimal satu repo single-service sebagai pembanding bila tersedia.

Checklist:
- [ ] Update caller workflow untuk memakai reusable workflow external.
- [ ] Ganti referensi `@main` menjadi `@v1`.
- [ ] Pindahkan logic inline yang generik ke reusable workflows.
- [ ] Pastikan secret dan vars tersedia di caller repo.
- [ ] Tambahkan concurrency dan environment protection bila perlu.

### Phase 4: Validation

Checklist:
- [ ] Dev CI berjalan.
- [ ] Staging CI berjalan.
- [ ] Hotfix or production CI berjalan.
- [ ] Dynamic matrix berjalan untuk monorepo.
- [ ] Single-service flow berjalan tanpa change detection.
- [ ] Build, scan, push, dan deploy menghasilkan output yang konsisten.
- [ ] Notification berjalan untuk success dan failure.
- [ ] Tidak ada dependency terhadap self-hosted runner.

### Phase 5: Scale Adoption

Setelah pilot stabil:
- onboard repo lain bertahap,
- kumpulkan feedback contract,
- tambahkan capability baru tanpa breaking change,
- catat semua perubahan melalui release notes.

## Caller Migration Guidance

### Before

```yaml
jobs:
  detect:
    uses: ./.github/workflows/ci-change-detection-reusable.yml
```

### After

```yaml
jobs:
  detect:
    uses: mta-tech/reusable-workflows/.github/workflows/ci-change-detection-reusable.yml@v1
```

### Runner Guidance

- Untuk job normal di caller repo, gunakan `runs-on: ubuntu-latest` bila memang job tersebut berjalan langsung di caller.
- Untuk job yang memanggil reusable workflow lewat `uses:`, `runs-on` tidak didefinisikan di caller job.
- Runner dieksekusi sesuai definisi di reusable workflow.

## Operational Guardrails

- Gunakan environment protection untuk staging dan production.
- Gunakan `concurrency` agar deploy branch yang sama tidak overlap.
- Fail fast jika input penting tidak valid.
- Jangan update semua consumer sekaligus; gunakan canary adoption.
- Sediakan rollback dengan mengembalikan referensi workflow ke inline/local workflow atau tag version sebelumnya.

## Rollback Plan

Jika ada issue setelah adopsi:

1. Revert caller repo ke workflow reference sebelumnya.
2. Pin consumer ke tag workflow sebelumnya, misalnya dari `@v1.2.0` kembali ke `@v1.1.0`.
3. Jika ada breaking issue besar, stop moving major tag `v1` sampai fix tervalidasi.
4. Self-hosted runner tidak menjadi rollback utama kecuali ada dependency tooling yang memang belum bisa dipindah ke GitHub-hosted runner.

## Success Criteria

- [ ] Repo `mta-tech/reusable-workflows` published dan terdokumentasi.
- [ ] Semua reusable workflows punya contract yang jelas dan konsisten.
- [ ] Semua workflow production consumer menggunakan tagged release, bukan `@main`.
- [ ] Pilot monorepo berhasil memakai change detection plus matrix build.
- [ ] Pilot single-service repo berhasil memakai build/deploy workflow yang sama.
- [ ] Semua workflow berjalan di GitHub-hosted runners tanpa dependensi ke self-hosted runner.
- [ ] Permissions dan secret usage sesuai prinsip least privilege.
- [ ] Third-party actions dipin ke immutable reference.
- [ ] Rollback ke versi workflow sebelumnya bisa dilakukan tanpa perubahan besar.

## Immediate Next Steps

1. Rename workflow files agar sesuai contract platform.
2. Tambahkan `README.md` dan docs contract untuk semua reusable workflows.
3. Review dan harden security baseline pada seluruh workflow.
4. Publish repo sebagai `internal`.
5. Migrasikan `test-pipeline` sebagai pilot ke `@v1`.
6. Validasi satu use case monorepo dan satu use case single-service.

## References

- [GitHub Actions: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions: Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub Actions: Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

---

**Created:** 2026-04-01
**Last Updated:** 2026-04-01
**Status:** Draft - Revised for Platform Rollout
