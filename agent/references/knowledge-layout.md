# 知识库布局契约（Agent SSOT）

> **定位**：三层 `{DOC_DIR}` **路径**、overview 缓冲区、联邦流水线、技能落点与 SDD×`KNOWLEDGE_TYPE` 的唯一 Agent 侧真源。  
> **不分管**：文件四类分型、per-entity Profile、frontmatter/正文结构 → [okf-spec.md](../knowledge/okf-spec.md)；实体 ID 前缀 → [naming-conventions.md](../knowledge/naming-conventions.md)。  
> 会话工作稿路径见 [session-spec-path.md](session-spec-path.md)；闸门总表见 [CONVENTIONS.md](../rules/CONVENTIONS.md#artifact-gates)；推进环见 [unit-cycle-protocol.md](unit-cycle-protocol.md)。

**最后更新**: 2026-07-18

---

## 三层文档根

| 文档根 `{DOC_DIR}` | 人类入口 | 五视角知识 | overview 缓冲区 | 联邦镜像槽位 |
| --- | --- | --- | --- | --- |
| `application/` | [application/README.md](../../application/README.md) | [application/knowledge/](../../application/knowledge/README.md) | — | — |
| `system/` | [system/README.md](../../system/README.md) | [system/knowledge/](../../system/knowledge/README.md) | [system/knowledge/overview/](../../system/knowledge/overview/NAME-overview.md) | `system/application-{APPNAME}/` |
| `company/` | [company/README.md](../../company/README.md) | [company/knowledge/](../../company/knowledge/README.md) | [company/knowledge/overview/](../../company/knowledge/overview/NAME-overview.md) | `company/system-{SYSNAME}/` |

**路径约定**：三层五视角均为 **`{DOC_DIR}/knowledge/`**（legacy `architecture/` / `ea/` 已废弃）。应用层无 overview；本层首次实体（API/TBL/MW/CMP）见 [application/DESIGN.md](../../application/DESIGN.md) §2.2.1。

---

## overview 缓冲区

| 库 | 路径模式 | 新建模板 | 第三列写入技能 |
| --- | --- | --- | --- |
| 系统库 | `system/knowledge/overview/{APPNAME}-overview.md` | 拷 `NAME-overview.md`，替换 `NAME`/`APPNAME` | **docs-distill**（上行）、**docs-extract**、**docs-tag** |
| 公司库 | `company/knowledge/overview/{NAME}-overview.md` | 拷 `NAME-overview.md`，替换 `NAME` | **docs-extract**、**docs-archive**、**docs-tag**（**非** docs-distill 落盘目标） |

**表行真源**：同层 `overview/NAME-overview.md` 五视角表 ↔ 同层五视角 **README 表行**；副标题锚点与各章 `##` 标题对齐。

**第三列规则**（去重、delta、A/U/D）：[federation-spec.md](../skills/docs-distill/references/federation-spec.md)「规则（第三列）」。

---

## 系统库 overview 主标题行序（摘要）

自上而下逐节，勿跳行：

- 业务：概述 → 域划分 → 术语 → 流程 → 能力地图 → 业务规则与策略
- 产品：概述 → 产品架构 → 信息架构 → 产品功能 → 用户旅程与场景 → 版本管理与发布 → 产品运营支撑 → 多端策略
- 应用：系统概述 → 应用架构 → 领域模型 → 服务设计 → 领域能力 → 集成架构 → 服务间交互 → 接口管理 → 多租户多环境 → ADR
- 技术：技术概述 → 基础设施 → 中间件 → **性能扩展 → 高可用** → 可观测性
- 数据：数据概述 → 数据模型 → 数据存储 → 数据分析 → 数据流转

公司库行序见 `company/knowledge/overview/NAME-overview.md` 与同层 README。

---

## 知识流水线

```text
应用库（本地 path，HEAD） ──docs-link──► system/knowledge-links.yaml（建联 + 建槽位）
                              └──► 应用库 knowledge-parent.yaml（1:1 上级 identity）
应用库（本地 path，HEAD） ──docs-pull──► system/application-{APPNAME}/（联邦槽位，不可被 knowledge 引用）
系统库（本地 path，HEAD） ──docs-link──► company/knowledge-links.yaml（建联 + 建槽位）
                              └──► 系统库 knowledge-parent.yaml
系统库（本地 path，HEAD） ──docs-pull──► company/system-{SYSNAME}/（联邦槽位，不可被 knowledge 引用）
         │
         ▼ docs-distill（仅系统 overview）
system/knowledge/overview/{APPNAME}-overview.md
         │ docs-extract（任意源 → 系统/公司 overview）
         │ docs-tag（关键词 ✅、架构摘录）
         ▼ docs-archive
system/knowledge/{business,product,application,data,technical}/
company/knowledge/{business,product,application,data,technical}/
```

---

## 写入路径与协议（非 hook）

写前拦截 **已移除**（`agent/hooks.json` 的 `preToolUse` 为空）。overview / 索引写入靠技能内参数向导与推进协议：

| 技能 | 典型写入 | 协议 |
| --- | --- | --- |
| docs-distill / docs-extract | `system|company/knowledge/overview/*.md` 第三列等 | 语义族：澄清 → 生成 → 烤干 |
| docs-archive | overview 回写 + 视角章节落盘 | 同上（确认书=意图澄清） |
| docs-indexing | `INDEX-GUIDE.md`、`*/changelogs/INDEXING-LOG.md` | 同上 |
| docs-tag | overview 附录 / ✅ / 摘录 | 轻流程 + 轻量校核 |

总表见 [CONVENTIONS.md](../rules/CONVENTIONS.md#artifact-gates)。

---

## SDD 与 KNOWLEDGE_TYPE

| 模式 | 方案/分析落盘 | 架构输入 | PRD/ASD/DSD |
| --- | --- | --- | --- |
| `application`（默认） | `{DOC_DIR}/solutions/`、`analysis/` | 应用上下文 | `{DOC_DIR}/requirements/**/` |
| `system` | `system/solutions/`、`system/analysis/` | [system/knowledge/](../../system/knowledge/README.md) | 联邦 ASD 概要；详设 → 应用库 `/sdx-design` |
| `company` | `company/solutions/`、`company/analysis/` | [company/knowledge/](../../company/knowledge/README.md) | 公司 ANALYSIS 拆解系统归属；各系统 PRD/ASD/DSD 在对应 **`system/requirements/`** |

详见 [sdx-architect/references/knowledge-type-modes.md](../skills/sdx-architect/references/knowledge-type-modes.md)。

---

## 相关 Skill

| 场景 | 技能 |
| --- | --- |
| 上行蒸馏 | docs-distill |
| 任意源 → overview | docs-extract |
| overview → 视角章节 | docs-archive |
| 关键词 / 摘录 | docs-tag |
| 索引地图 | docs-indexing |
| 入口契约 | docs-agent |
