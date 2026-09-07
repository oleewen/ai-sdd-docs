# 知识库治理规则

本文件只定义 **三层知识库职责边界** 与 **业务 knowledge 引用边界**。组件索引、使用顺序见同目录 [README.md](README.md)。

协作闸门与编码规范见 [CONVENTIONS.md](../rules/CONVENTIONS.md)。路径/overview/流水线见 [knowledge-layout.md](../references/knowledge-layout.md)。

## 使命

决策 **透明、一致、可追溯**，避免架构随口语漂移。

## 三层职责边界

| 层级 | 目录 | 治理职责 | 实体 SSOT |
| --- | --- | --- | --- |
| 公司 | `company/` | 公司级 EA 叙事、跨系统方案与分析、系统槽位 | BD、PL、SYS、CAP、MDG、TPL（公司级目录实体） |
| 系统 | `system/` | 系统级架构聚合、应用镜像槽位、蒸馏归档 | BSD、PM、APP、DS、TSD 等（见各层 DESIGN §2.2.1） |
| 应用 | `application/` | 五视角实体事实源、SDD 阶段交付 | BC、AGG、AB、FT、UC、MS、API、ENT、MW、CMP 等 |

**命名、术语与 OKF 文件分型**：统一以 `agent/knowledge/` 为准（见 [README.md](README.md)）；`system/` / `company/` 维护本层目录语义与映射。

## 业务 knowledge 引用边界

**适用范围**：仅 `application|system|company` 下 `*/knowledge/**`（含 overview、视角章、per-entity、meta、README）。**不含** `agent/knowledge/**`（Agent 元知识可链规则与布局文档）。

**层级方向**（高 → 低）：`company` > `system` > `application`。只许向上引用；禁止引下层 knowledge 与联邦槽位（`system/application-*`、`company/system-*`）。

| 允许 | 禁止 |
| --- | --- |
| 同层 `…/knowledge/**` 内互引（bundle-relative） | 引同层 knowledge **外**（`adr/`、`solutions/`、`analysis/`、`requirements/`、`DESIGN.md`、`INDEX-GUIDE.md`、根 `index.md`、`agent/**` 等） |
| 有 `{DOC_ROOT}/knowledge-parent.yaml`：上层实体 Markdown 链到 **首次定义层 SSOT 文件的 HTTP**（见下） | 手写 `../` 爬层、仓库相对跨 `DOC_DIR`、`/company/knowledge/...` 逻辑前缀、与生成函数结果不一致的 URL |
| 无 `knowledge-parent.yaml`：正文只写实体 ID / `full_id`（纯文本） | 无 parent 时仍写跨层 HTTP 或跨层文件路径 |
| `resource` / 依据段：外部 **URI、表名、API 名、仓名**（非库外文档相对路径） | Markdown 链或路径字面量指向库外 **文档文件**（ADR 等：**留字去链**） |

**parent（1:1）**：`docs-link` 在下级写入 `{DOC_ROOT}/knowledge-parent.yaml` 单对象 `parent:`：`knowledge_type`、`repository`、`path`、`doc_dir`、`ref`（默认 `main`）。上级 `knowledge-links.yaml` 仍是向下建联 SSOT。一个 application 只对应一个 system parent，一个 system 只对应一个 company parent；换上级即覆盖并替换旧 HTTP 前缀。`docs-install` 重装须保留已有 parent。company 无此文件。

**HTTP 生成（唯一函数；技能 / docs-link / 校验共用）**：输入 `full_id` 与首次定义层。沿 parent 链走到该层，解析根优先 `{repository}/{doc_dir}`，否则 `{path}/{doc_dir}`。`repository`：SSH→HTTPS、去 `.git`；GitHub `/blob/{ref}/`，GitLab `/-/blob/{ref}/`，Gitee `/blob/{ref}/`；未知宿主不写 HTTP，只用 `path`+`doc_dir`（本机不存在则正文保持 ID）。文件相对路径用 **目标层** `entity_relpath`，不链中间层 stub。禁止手写与推导不同的 href。`docs-link` 变更 `repository`/`ref`/`doc_dir` 时扫描下级 `*/knowledge/**` 替换旧 web_base；`unlink` 能改为纯 ID 则改，否则停并列清单。

**下层 stub**：首次定义在上层的实体，下层可留同 `full_id` 的薄 reference（`definition_scope: reference`，`layer_scope` 为本层），不重复字段语义；`parent_id` 仍在本 bundle 解析。有 parent 时 stub 的关系/依据段用上述 HTTP 指向上层 SSOT。

**校验（默认离线）**：有 parent 则 href 必须等于「推导 web_base + 目标层 relpath」；`path` 在本机存在时再查文件。不 HTTP GET。无 parent 出现跨层 HTTP 则失败。不得把 `/knowledge/...` 回退到下游 bundle。

**读写分离**：技能可读 knowledge 外源（solutions、槽位等）；**落盘进** `*/knowledge/**` 的正文、链接、路径字面量、frontmatter 外指须满足上表。脚本实现（生成函数、docs-link 写 parent、校验）另批落地，本节为行为契约。

**违规处理（写技能）**：能机械修复则修（库外/下层去链或纯 ID；跨层手写路径改为生成函数 HTTP，无 parent 则纯 ID）；目标层或实体不明则停，列清单交人。

**SSOT**：本节；OKF 段结构对齐见 [okf-spec.md](okf-spec.md) §4。

## 设计入口

- [application/DESIGN.md](../../application/DESIGN.md)
- [system/DESIGN.md](../../system/DESIGN.md)
- [company/DESIGN.md](../../company/DESIGN.md)
