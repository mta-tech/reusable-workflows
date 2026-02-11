# Reusable Docker Build Workflow

A GitHub Actions reusable workflow for pulling the latest code and building Docker images without pushing them to a registry.

## Files

- `.github/workflows/docker-build-only.yml` - The reusable workflow
- `.github/workflows/example-call-docker-build.yml` - Example usage

## Usage

### Basic Example

```yaml
name: Build Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    uses: ./.github/workflows/docker-build-only.yml
    with:
      image_name: 'my-org/my-app'
```

### With Custom Inputs

```yaml
jobs:
  build:
    uses: ./.github/workflows/docker-build-only.yml
    with:
      image_name: 'my-org/my-app'
      dockerfile_path: 'docker/Dockerfile'
      build_context: '.'
      image_tag: 'v1.0.0'
      platform: 'linux/amd64'
      build_args: '{"NODE_ENV":"production"}'
      cache: true
```

### Multiple Tags (Matrix Build)

```yaml
jobs:
  build:
    strategy:
      matrix:
        tag: ['v1.0.0', 'v1.1.0', 'latest']
    uses: ./.github/workflows/docker-build-only.yml
    with:
      image_name: 'my-org/my-app'
      image_tag: ${{ matrix.tag }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `image_name` | Name of the Docker image to build | Yes | - |
| `dockerfile_path` | Path to the Dockerfile | No | `Dockerfile` |
| `build_context` | Build context path | No | `.` |
| `image_tag` | Tag for the Docker image | No | `latest` |
| `platform` | Target platform (e.g., linux/amd64, linux/arm64) | No | `linux/amd64` |
| `build_args` | Build arguments as JSON string | No | `{}` |
| `cache` | Enable Docker build cache | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `image_digest` | Digest of the built image |
| `image_id` | ID of the built image |

### Using Outputs

```yaml
jobs:
  build:
    uses: ./.github/workflows/docker-build-only.yml
    with:
      image_name: 'my-org/my-app'

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download image artifact
        uses: actions/download-artifact@v4
        with:
          name: docker-image-latest

      - name: Load image
        run: docker load -i image.tar

      - name: Run tests in container
        run: docker run --rm my-org/my-app npm test
```

## Features

- Pulls the latest code automatically
- Supports multi-platform builds (linux/amd64, linux/arm64, etc.)
- GitHub Actions cache support for faster builds
- Build arguments support for customizing the build
- Exports image as artifact (available for download)
- Returns image digest and ID as outputs
- Does NOT push to any registry

## Workflow Permissions

Ensure your workflow has the necessary permissions:

```yaml
permissions:
  contents: read
  actions: write  # For caching and artifacts
```
