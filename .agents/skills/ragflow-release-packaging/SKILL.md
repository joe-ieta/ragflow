---
name: ragflow-release-packaging
description: RAGFlow local release packaging workflow for Docker-based offline base environment and application images. Use this skill when updating E:\CodexDev\ragflow-release, rebuilding AMD64 or ARM64 images, validating release completeness, or changing start/stop scripts.
---

# RAGFlow Release Packaging

Use this skill for any change that touches the local release bundle under `E:\CodexDev\ragflow-release`, including base service images, application images, offline tar archives, and platform-specific start/stop scripts.

## Release Layout

The release bundle is split into two sibling directories:

```text
E:\CodexDev\ragflow-release\
  ragflow-base-env\
  ragflow-app\
```

`ragflow-base-env` owns infrastructure services:

- Elasticsearch: `elasticsearch:8.11.3`
- MySQL: `mysql:8.0.39`
- MinIO: `pgsty/minio:RELEASE.2026-03-25T00-00-00Z`
- Redis-compatible Valkey: `valkey/valkey:8`

`ragflow-app` owns the RAGFlow application image:

- Runtime image name: `ragflow-local:0.26.3`
- AMD64 tar: `ragflow-app/images/linux-amd64/ragflow-local_0.26.3.tar`
- ARM64 tar: `ragflow-app/images/linux-arm64/ragflow-local_0.26.3.tar`

Both platforms intentionally reuse the same runtime image tag. Start scripts must validate the local image architecture before skipping `docker load`.

## Build Order

Build the dependency image before the application image. The application `Dockerfile` uses `infiniflow/ragflow_deps:latest` as a BuildKit bind source.

For AMD64:

```powershell
cd E:\CodexDev\ragflow
docker buildx build --platform linux/amd64 -f ragflow_deps/Dockerfile -t infiniflow/ragflow_deps:latest --load ragflow_deps
docker buildx build --platform linux/amd64 -t ragflow-local:0.26.3 --load .
docker save -o E:\CodexDev\ragflow-release\ragflow-app\images\linux-amd64\ragflow-local_0.26.3.tar ragflow-local:0.26.3
```

For ARM64:

```powershell
cd E:\CodexDev\ragflow
docker buildx build --platform linux/arm64 -f ragflow_deps/Dockerfile -t infiniflow/ragflow_deps:latest --load ragflow_deps
docker buildx build --platform linux/arm64 -t ragflow-local:0.26.3 --load .
docker save -o E:\CodexDev\ragflow-release\ragflow-app\images\linux-arm64\ragflow-local_0.26.3.tar ragflow-local:0.26.3
```

Important: `--load` writes the selected platform image into the local Docker image store. After building ARM64, `ragflow-local:0.26.3` and `infiniflow/ragflow_deps:latest` may point to ARM64 on an AMD64 host. This is expected, but start scripts must reload the correct platform tar before running.

## Script Rules

Windows entry points:

- `ragflow-base-env/start-base-env.ps1`
- `ragflow-base-env/stop-base-env.ps1`
- `ragflow-app/start-ragflow.ps1`
- `ragflow-app/stop-ragflow.ps1`

Ubuntu AMD64 entry points:

- `ragflow-base-env/scripts/ubuntu-amd64/start.sh`
- `ragflow-base-env/scripts/ubuntu-amd64/stop.sh`
- `ragflow-app/scripts/ubuntu-amd64/start.sh`
- `ragflow-app/scripts/ubuntu-amd64/stop.sh`

Ubuntu ARM64 entry points:

- `ragflow-base-env/scripts/ubuntu-arm64/start.sh`
- `ragflow-base-env/scripts/ubuntu-arm64/stop.sh`
- `ragflow-app/scripts/ubuntu-arm64/start.sh`
- `ragflow-app/scripts/ubuntu-arm64/stop.sh`

Application start scripts must:

1. Check whether base services `es01`, `mysql`, `minio`, and `redis` are already running under compose project `ragflow-base-env`.
2. Start the base environment only when required.
3. Check local `ragflow-local:0.26.3` architecture.
4. Load the matching platform tar if the image is missing or has the wrong architecture.
5. Start `ragflow-app` with `docker-compose.ragflow.yml`.

Windows `start-ragflow.ps1` expects `linux/amd64`. Ubuntu AMD64 expects `linux/amd64`. Ubuntu ARM64 expects `linux/arm64`.

## Validation Checklist

Run these checks after every release update:

```powershell
docker compose --project-name ragflow-base-env -f E:\CodexDev\ragflow-release\ragflow-base-env\docker-compose.base-env.yml config --quiet
docker compose --project-name ragflow-app -f E:\CodexDev\ragflow-release\ragflow-app\docker-compose.ragflow.yml config --quiet
```

Check image metadata:

```powershell
docker image inspect ragflow-local:0.26.3 --format "id={{.Id}} os={{.Os}} arch={{.Architecture}} size={{.Size}} entrypoint={{json .Config.Entrypoint}} workdir={{.Config.WorkingDir}}"
```

Check application tar platform metadata by reading the OCI index. The AMD64 application tar must include a `linux/amd64` manifest; the ARM64 application tar must include a `linux/arm64` manifest.

Check hashes:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath E:\CodexDev\ragflow-release\ragflow-app\images\linux-amd64\ragflow-local_0.26.3.tar
Get-FileHash -Algorithm SHA256 -LiteralPath E:\CodexDev\ragflow-release\ragflow-app\images\linux-arm64\ragflow-local_0.26.3.tar
```

For AMD64 runtime validation on Windows:

```powershell
cd E:\CodexDev\ragflow-release\ragflow-app
.\start-ragflow.ps1
```

Expected runtime signs:

- Base services healthy: Elasticsearch, MySQL, MinIO, Redis.
- `ragflow-app` is running.
- Logs show `RAGFlow server is ready`.
- Web UI responds with HTTP 200 at `http://127.0.0.1:8080`.
- API port `9380` is listening. The root path may return HTTP 404 because no root route is defined.

Stop application only:

```powershell
.\stop-ragflow.ps1
```

Stop application and base environment:

```powershell
.\stop-ragflow.ps1 -StopBase
```

## Known Pitfalls

- Do not rely on image tag existence alone. `ragflow-local:0.26.3` may point to either AMD64 or ARM64 depending on the most recent `docker load` or `buildx --load`.
- Do not overwrite unrelated files in `E:\CodexDev\ragflow-release`; this folder is outside the repo workspace and changes require explicit filesystem approval.
- The app image is large. Avoid unconditional `docker load` in start scripts; load only when the image is missing or has the wrong architecture.
- `infiniflow/ragflow_deps:latest` must match the target platform before building the app image.
- ARM64 builds can expose architecture-specific issues. The Dockerfile has historical references to `chrome-linux64` and `chromedriver-linux64`; validate browser-related runtime behavior separately if browser automation features are required.
- PowerShell here-strings can corrupt Markdown code spans if backticks are not treated carefully. Prefer UTF-8 no-BOM writes and verify generated Markdown with explicit reads.

