# RAGFlow Project Instructions for GitHub Copilot

This file provides context, build instructions, and coding standards for the RAGFlow project.
It is structured to follow GitHub Copilot's [customization guidelines](https://docs.github.com/en/copilot/concepts/prompting/response-customization).

## 1. Project Overview
RAGFlow is an open-source RAG (Retrieval-Augmented Generation) engine based on deep document understanding. It is a full-stack application with a Python backend and a React/TypeScript frontend.

- **Backend**: Python 3.10+ (Flask/Quart)
- **Frontend**: TypeScript, React, UmiJS
- **Architecture**: Microservices based on Docker.
  - `api/`: Backend API server.
  - `rag/`: Core RAG logic (indexing, retrieval).
  - `deepdoc/`: Document parsing and OCR.
  - `web/`: Frontend application.

## 2. Directory Structure
- `api/`: Backend API server (Flask/Quart).
  - `apps/`: API Blueprints (Knowledge Base, Chat, etc.).
  - `db/`: Database models and services.
- `rag/`: Core RAG logic.
  - `llm/`: LLM, Embedding, and Rerank model abstractions.
- `deepdoc/`: Document parsing and OCR modules.
- `agent/`: Agentic reasoning components.
- `web/`: Frontend application (React + UmiJS).
- `docker/`: Docker deployment configurations.
- `sdk/`: Python SDK.
- `test/`: Backend tests.

## 3. Build Instructions

### Backend (Python)
The project uses **uv** for dependency management.

1. **Setup Environment**:
   ```bash
   uv sync --python 3.13 --all-extras
   uv run python3 ragflow_deps/download_deps.py
   ```

2. **Run Server**:
   - **Pre-requisite**: Start dependent services (MySQL, ES/Infinity, Redis, MinIO).
     ```bash
     docker compose -f docker/docker-compose-base.yml up -d
     ```
   - **Launch**:
     ```bash
     source .venv/bin/activate
     export PYTHONPATH=$(pwd)
     bash docker/launch_backend_service.sh
     ```

### Frontend (TypeScript/React)
Located in `web/`.

1. **Install Dependencies**:
   ```bash
   cd web
   npm install
   ```

2. **Run Dev Server**:
   ```bash
   npm run dev
   ```
   Runs on port 8000 by default.

### Docker Deployment
To run the full stack using Docker:
```bash
cd docker
docker compose -f docker-compose.yml up -d
```

## 4. Testing Instructions

### Backend Tests
- **Run All Tests**:
  ```bash
  uv run pytest
  ```
- **Run Specific Test**:
  ```bash
  uv run pytest test/test_api.py
  ```

### Frontend Tests
- **Run Tests**:
  ```bash
  cd web
  npm run test
  ```

## 5. Coding Standards & Guidelines
- **Python Formatting**: Use `ruff` for linting and formatting.
  ```bash
  ruff check
  ruff format
  ```
- **Frontend Linting**:
  ```bash
  cd web
  npm run lint
  ```
- **Git Hooks**: Run this once after the first clone to enable local Git hooks.
  ```bash
  lefthook install
  lefthook run pre-commit --all-files
  ```

## 6. Local Release Packaging
When updating the local Docker release bundle under `E:\CodexDev\ragflow-release`, use the project skill `.agents/skills/ragflow-release-packaging/SKILL.md`.

Key constraints:
- Keep the release split into `ragflow-base-env` and `ragflow-app`.
- Preserve both `linux-amd64` and `linux-arm64` offline image directories.
- Validate image architecture before skipping `docker load`; the shared tag `ragflow-local:0.26.3` can point to either AMD64 or ARM64 after a build.
- Re-run compose parsing and tar/platform checks after changing release scripts or images.
