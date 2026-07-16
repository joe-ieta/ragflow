---
name: ragflow-release-packaging
description: RAGFlow application-only local release packaging workflow. Use this skill when updating E:\CodexDev\ragflow-release, rebuilding AMD64 or ARM64 RAGFlow application images, validating release completeness, or changing start/stop scripts that integrate with E:\CodexDev\ieta-znz-deploy.
---

# RAGFlow Release Packaging

Use this skill for changes that touch the local RAGFlow release bundle under `E:\CodexDev\ragflow-release`.

The RAGFlow release is an **application release only**. Do not package or maintain third-party base containers here. MySQL, MinIO, Valkey, Elasticsearch 8, and other shared infrastructure containers are owned by the sibling deployment project:

```text
E:\CodexDev\ieta-znz-deploy
```

Read and follow the documents in `E:\CodexDev\ieta-znz-deploy` before changing RAGFlow release scripts. Do not modify `ieta-znz-deploy` from this project unless the user explicitly asks for work in that project.

## Release Layout

The expected RAGFlow release layout is:

```text
E:\CodexDev\
  ieta-znz-deploy\       # shared third-party base containers
  ragflow-release\       # RAGFlow application release
    docker-compose.ragflow.yml
    .env
    README.md
    start-ragflow.ps1
    stop-ragflow.ps1
    status-ragflow.ps1
    check-release.ps1
    images\
      linux-amd64\
      linux-arm64\
    scripts\
      ubuntu-amd64\
      ubuntu-arm64\
```

Do not recreate any RAGFlow-owned base environment release split. Historical folders may exist, but new release work should produce only RAGFlow application artifacts.

## Base Environment Contract

RAGFlow depends on the `ragflow` application manifest in `ieta-znz-deploy`:

```text
E:\CodexDev\ieta-znz-deploy\apps\ragflow.env
```

Required base capabilities:

- `mysql`
- `minio`
- `valkey`
- `es8`

Expected shared Docker network:

```text
ieta-znz-deploy
```

RAGFlow application containers must join this network as an external network. They must use base service names, not host ports, for container-to-container connections.

RAGFlow-compatible service values:

```text
MYSQL_HOST=mysql8
MYSQL_PORT=3306
MYSQL_DBNAME=rag_flow
MYSQL_USER=rag_flow
MYSQL_PASSWORD=infini_rag_flow
MINIO_HOST=minio
MINIO_USER=ieta_admin
MINIO_PASSWORD=infini_rag_flow
REDIS_HOST=valkey
REDIS_PORT=6379
REDIS_PASSWORD=infini_rag_flow
ES_HOST=es8-ragflow
ELASTIC_PASSWORD=infini_rag_flow
```

Important: `docker/service_conf.yaml.template` appends ports and schemes for some values. Do not set `MINIO_HOST=minio:9000` or `ES_HOST=http://es8-ragflow:9200` in the RAGFlow app `.env`, because that produces malformed values such as `minio:9000:9000` or `http://http://...:9200`.

If `ieta-znz-deploy` has an incompatible template for RAGFlow, document it as an optimization suggestion in the RAGFlow release notes. Do not silently edit `ieta-znz-deploy`.

## Application Image

Runtime image name:

```text
ragflow-local:0.26.3
```

Platform tar files:

```text
ragflow-release/images/linux-amd64/ragflow-local_0.26.3.tar
ragflow-release/images/linux-arm64/ragflow-local_0.26.3.tar
```

Both platforms intentionally reuse the same runtime image tag. Start scripts must validate local image architecture before skipping `docker load`.

## Build Order

Build the dependency image before the application image. The application `Dockerfile` uses `infiniflow/ragflow_deps:latest` as a BuildKit bind source.

For AMD64:

```powershell
cd E:\CodexDev\ragflow
docker buildx build --platform linux/amd64 -f ragflow_deps/Dockerfile -t infiniflow/ragflow_deps:latest --load ragflow_deps
docker buildx build --platform linux/amd64 -t ragflow-local:0.26.3 --load .
docker save --platform linux/amd64 -o E:\CodexDev\ragflow-release\images\linux-amd64\ragflow-local_0.26.3.tar ragflow-local:0.26.3
```

For ARM64:

```powershell
cd E:\CodexDev\ragflow
docker buildx build --platform linux/arm64 -f ragflow_deps/Dockerfile -t infiniflow/ragflow_deps:latest --load ragflow_deps
docker buildx build --platform linux/arm64 -t ragflow-local:0.26.3 --load .
docker save --platform linux/arm64 -o E:\CodexDev\ragflow-release\images\linux-arm64\ragflow-local_0.26.3.tar ragflow-local:0.26.3
```

Important: `--load` writes the selected platform image into the local Docker image store. After building ARM64, `ragflow-local:0.26.3` and `infiniflow/ragflow_deps:latest` may point to ARM64 on an AMD64 host. This is expected, but start scripts must reload the correct platform tar before running.

## Script Rules

Windows entry points:

- `start-ragflow.ps1`
- `stop-ragflow.ps1`
- `status-ragflow.ps1`
- `check-release.ps1`

Ubuntu AMD64 entry points:

- `scripts/ubuntu-amd64/start.sh`
- `scripts/ubuntu-amd64/stop.sh`
- `scripts/ubuntu-amd64/status.sh`

Ubuntu ARM64 entry points:

- `scripts/ubuntu-arm64/start.sh`
- `scripts/ubuntu-arm64/stop.sh`
- `scripts/ubuntu-arm64/status.sh`

Application start scripts must:

1. Locate sibling `ieta-znz-deploy` relative to `ragflow-release` or allow an override parameter.
2. Call the `ieta-znz-deploy` app-base start entry for `ragflow`.
3. Check that required base services are running: `mysql8`, `minio`, `valkey`, and `es8-ragflow`.
4. Check local `ragflow-local:0.26.3` architecture.
5. Load the matching platform tar only when the image is missing or has the wrong architecture.
6. Start RAGFlow with `docker-compose.ragflow.yml`.

Stop scripts must stop only RAGFlow application containers by default. They must not stop or remove shared `ieta-znz-deploy` services unless a clearly named explicit flag is used and documented.

## Validation Checklist

Run this check after every release update:

```powershell
docker compose --project-name ragflow-app -f E:\CodexDev\ragflow-release\docker-compose.ragflow.yml config --quiet
```

Check base environment integration:

```powershell
cd E:\CodexDev\ieta-znz-deploy
.\status-app-base.ps1 -App ragflow
```

Check image metadata:

```powershell
docker image inspect ragflow-local:0.26.3 --format "id={{.Id}} os={{.Os}} arch={{.Architecture}} size={{.Size}} entrypoint={{json .Config.Entrypoint}} workdir={{.Config.WorkingDir}}"
```

Check hashes:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath E:\CodexDev\ragflow-release\images\linux-amd64\ragflow-local_0.26.3.tar
Get-FileHash -Algorithm SHA256 -LiteralPath E:\CodexDev\ragflow-release\images\linux-arm64\ragflow-local_0.26.3.tar
```

Expected runtime signs:

- `ieta-znz-deploy` services for RAGFlow are running: MySQL, MinIO, Valkey, Elasticsearch 8.
- `ragflow-app` is running.
- Logs show `RAGFlow server is ready`.
- Web UI responds with HTTP 200 at `http://127.0.0.1:8080` or the configured web port.
- API port `9380` is listening. The root path may return HTTP 404 because no root route is defined.

## Known Pitfalls

- Do not package MySQL, MinIO, Valkey, Elasticsearch, or other third-party base images under `ragflow-release`.
- Do not rely on image tag existence alone. `ragflow-local:0.26.3` may point to either AMD64 or ARM64 depending on the most recent `docker load` or `buildx --load`.
- Do not overwrite unrelated files in `E:\CodexDev\ragflow-release`; this folder is outside the repo workspace and changes require explicit filesystem approval.
- The app image is large. Avoid unconditional `docker load` in start scripts; load only when the image is missing or has the wrong architecture.
- `infiniflow/ragflow_deps:latest` must match the target platform before building the app image.
- ARM64 builds can expose architecture-specific issues. The Dockerfile has historical references to `chrome-linux64` and `chromedriver-linux64`; validate browser-related runtime behavior separately if browser automation features are required.
- PowerShell here-strings can corrupt Markdown code spans if backticks are not treated carefully. Prefer UTF-8 no-BOM writes and verify generated Markdown with explicit reads.
