# 开发与上游同步

## 分支职责

| 引用 | 职责 |
| --- | --- |
| `upstream/main` | RAGFlow 官方代码。远端为 `infiniflow/ragflow` |
| 本地 `main` | 只跟踪 `upstream/main`，同步使用 fast-forward |
| 本地 `agentic-rag` | 领域项目开发和独立发布。起点为原定制分支提交 `3facaf2f1`，保留三笔本地发布定制 |
| `origin` | 项目 fork `joe-ieta/ragflow`。经批准发布分支时使用 `origin/agentic-rag` |

最初的分支基线对应本项目 0.26.3 版本线。官方 `main` 可能跨越多个版本，先将官方跟踪更新至目标提交，再由项目单独决定升级窗口。

```powershell
git fetch --no-tags upstream main
git switch main
git merge --ff-only upstream/main
git switch agentic-rag
```

同步前检查工作区和工作树占用。准备吸收上游时，从 `agentic-rag` 建立单独的集成分支，在该分支合并显式记录的上游提交或摘取选定修复。复核解析、检索和 Agent API 契约、数据库迁移、文档引擎、镜像构建与共享基础环境，再把已验证的改动合入 `agentic-rag`。项目变更和发布标签归项目 fork。

## 目录与依赖边界

| 位置 | 职责 |
| --- | --- |
| `docs/agentic-rag/` | 设计、技术调研、开发和发布基线 |
| `agentic_rag/contracts/` | 领域接口契约、样例回包和后续兼容性约定 |
| `tools/agentic-rag/` | 本地验证、发布计划和候选镜像构建 |
| `agent/`、`rag/`、`deepdoc/`、`api/`、`web/` | 现有运行时。领域扩展经 API、适配器或工具契约接入 |

当前骨架以「付款送审预核」为首个边界。先确定申请行、里程碑、验收批的关系，以及合同、ERP、质量和档案的权威字段。实现顺序为 **业务只读适配 → 授权文档范围 → 证据核验 → 规则求值 → Agent 解释**。预核输出使用结构化契约；后续受控动作经既有流程和业务服务执行。

## 开发验证

在仓库根目录运行本地检查。需要 PowerShell 7.4+、Git 和 Docker Compose。

```powershell
pwsh -NoProfile -File tools/agentic-rag/check.ps1
```

检查覆盖 Git 差异格式、PowerShell 脚本语法、预核样例的 JSON Schema 校验和基线 Compose 配置解析。仅检查文档和契约时，可传 `-SkipCompose`。分支推送和以该分支为目标的 PR 会运行独立的项目检查工作流。

运行应用级测试时，按仓库根目录 [AGENTS.md](../../AGENTS.md) 安装 Python 3.13、uv 和前端依赖。涉及运行时的变更再按影响范围运行后端、前端或容器检查。真实付款流程接入前，用合成数据与历史样本覆盖缺签署件、版本冲突、部分验收、重复计付、来源超时和越权拒绝。
