# `promote-image-reusable.yml`

Reusable workflow untuk mempromosikan image container dari satu registry reference ke reference lain tanpa rebuild.

## Inputs

| Input | Required | Type | Default | Keterangan |
| --- | --- | --- | --- | --- |
| `source_image` | Yes | `string` | - | Full source image reference, misalnya `asia-southeast2-docker.pkg.dev/project/repo/app/service:v26.4.0`. |
| `target_image` | Yes | `string` | - | Full target image reference. |
| `project_id` | No | `string` | `""` | Project ID untuk konteks autentikasi Google Cloud. |
| `environment` | No | `string` | `""` | Label lingkungan untuk summary. |
| `enable_summary` | No | `boolean` | `true` | Publikasikan GitHub Step Summary. |

## Secrets

| Secret | Required | Keterangan |
| --- | --- | --- |
| `gcp_workload_identity_provider` | Yes | Workload Identity Provider Google Cloud. |
| `gcp_service_account` | Yes | Service account Google Cloud untuk read source image dan write target image. |

## Outputs

| Output | Keterangan |
| --- | --- |
| `promoted_image` | Full target image reference yang berhasil dipromote. |

## Perilaku

- Autentikasi ke Google Cloud menggunakan Workload Identity Federation.
- Mengonfigurasi Docker auth untuk host registry source dan target.
- Memvalidasi source image tersedia.
- Menjalankan `docker buildx imagetools create --tag <target> <source>` agar image dipromosikan tanpa rebuild.
- Memverifikasi target image setelah promote.
