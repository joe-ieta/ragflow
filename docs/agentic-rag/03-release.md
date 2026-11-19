# Agentic RAG 候选包构建与发布

独立发布线使用 `agentic-rag-v<版本>` 标签命名，以及 `ragflow-agentic-rag:<版本>-<短提交>-<架构>` 镜像标签。仓库中的官方发布工作流使用另一套标签和官方镜像目的地。本项目先在隔离构建工作区生成候选包，经验证后再在项目 fork 完成交付。

## 构建候选包

在 `agentic-rag` 上提交候选源码，准备 Docker Buildx、Compose、支持 `docker image save --platform` 的 Docker Engine、PowerShell 7.4+ 和可读取 Docker tar 的 `tar`。构建器需能执行 `linux/amd64`、`linux/arm64`。在专用构建宿主机串行执行，因为基线 Dockerfile 通过共享标签 `infiniflow/ragflow_deps:latest` 装载构建资源。

```powershell
pwsh -NoProfile -File tools/agentic-rag/check.ps1
pwsh -NoProfile -File tools/agentic-rag/build-release.ps1 -Version 0.1.0 -Plan
```

准备基线 Dockerfile 所需资源，建议依照 [仓库构建说明](../develop/build_docker_image.mdx)。资源下载及完整构建需要缓存、磁盘和依赖源可用。

```powershell
uv run python ragflow_deps/download_deps.py
pwsh -NoProfile -File tools/agentic-rag/build-release.ps1 -Version 0.1.0
```

脚本从干净的 `agentic-rag` 构建。依次准备同架构构建资源镜像、构建应用、导出单架构 tar、检查 OS、架构和源码提交标签并计算 SHA-256。候选物位于 `target/agentic-rag/<版本>-<短提交>/`。目录中的 `linux-amd64` 和 `linux-arm64` 分别保存应用镜像。两个镜像均验证完成后才生成 `release-manifest.json`。同路径已有文件时停止，失败目录可移出并保留以便诊断，之后重新构建。

## 验收与交付

1. 以清单为准核对两份 tar 的校验和、平台、镜像标签和提交号。只交付应用镜像。共享 MySQL、MinIO、Valkey、Elasticsearch 仍由 `ieta-znz-deploy` 提供。
2. 在隔离的目标部署配置中接入版本和平台对应的镜像。在实际部署前解析应用 Compose，确认外部网络、服务别名和数据隔离。通过 `ieta-znz-deploy` 的 `start-app-base -App ragflow` 入口准备基础服务，检查其状态。若启动流程复用本地镜像，先校验标签对应的架构。
3. 分别在两种平台完成解包、应用启动、API 和 Web 就绪检查、基础文档解析与检索，再按当前功能覆盖执行 Agentic RAG 样例。记录验证环境、版本、日志和结果。关闭应用后检查共享服务状态。发布前记录配置、数据库迁移兼容性及回退步骤。
4. 随应用镜像交付已验证的应用 Compose、环境变量示例、应用启停与状态检查入口以及版本说明。打包目录仅收录目标部署所需文件。现有共享基础环境以及历史发布目录由各自工程维护。
5. 验收后在同一提交上创建 `agentic-rag-v<版本>` 注解标签，将校验清单、候选物与发布说明交付至项目约定位置。发布流程保留上一可用版本的应用包和配置，回退时按迁移兼容性恢复。

构建清单证明候选镜像的内容校验和源码关联。部署冒烟、领域业务验收和正式分发是独立发布关卡。
