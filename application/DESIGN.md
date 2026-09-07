---
type: Design Document
title: 应用知识文档库 — 设计方案摘录
---
应用层设计摘录：原则、目录、跨层首次定义与映射。入口 [README.md](README.md)；九章 [INDEX-GUIDE.md](INDEX-GUIDE.md)；目录 [index.md](index.md)。

## 阅读顺序

1. [README.md](README.md) — 定位与 mode 路由
2. 本文 — 原则、§2.2.1、映射
3. [naming-conventions.md](../agent/knowledge/naming-conventions.md) — ID 规则
4. [knowledge/README.md](knowledge/README.md) — 五视角；字段见各 `*-meta.md`

## 1. 原则与约定

| 原则 | 说明 |
| --- | --- |
| **SSOT** | 实体只一处定义；他处仅 **ID 引用** |
| **联邦治理** | 系统库管边界与索引；应用库管实现细节并 **上行对齐** |
| **闭环** | solutions → analysis → requirements；knowledge = 事实源；上行 pull → distill（**仅**系统 overview）→ archive；**不**回写本库 knowledge |
| **五视角** | 业务 / 产品 / 应用 / 数据 / 技术；关联 ∈ meta 与 `{ID}.md`；**无**独立映射矩阵；legacy `*-entities.md` 已废弃 |
| **分层同构** | 五视角各层同构；首次定义见 §2.2.1 与 [naming-conventions.md](../agent/knowledge/naming-conventions.md) |

**指针**：根导航/meta → [docs-meta.md](docs-meta.md)；知识树 → [knowledge-meta.md](knowledge/knowledge-meta.md)；治理 → [agent/knowledge/README.md](../agent/knowledge/README.md)（三层边界 [knowledge-governance.md](../agent/knowledge/knowledge-governance.md)）；阶段约定 ∈ 各目录 `README.md`；`index.md` ← `/docs-okf`。

**OKF**：一实体一文件（`{ID}.md` + frontmatter + bundle-relative 跨链）；路径/type 见 naming-conventions §OKF。

**协同（目标态）**：应用仓维护文档树与 `manifest.md`；系统侧可抓 manifest 做一致性检查。

## 2. 目录与元模型

> 规范与 Agent 配置在仓库根 `agent/`，**不在** `application/` 内。

### 2.1 目录总表

| 目录 | 说明 |
| --- | --- |
| **knowledge/** | 五视角；本层首次实体 API / TBL / MW / CMP |
| **solutions/** | `SOLUTION-{IDEA-ID}.md` |
| **analysis/** | `ANALYSIS-{IDEA-ID}.md` |
| **requirements/** | `REQUIREMENT-{IDEA-ID}/`（规约可在包内 `specs/`） |
| **changelogs/** | 变更与索引运维（可选） |
| **adr/** | 应用层 ADR（`ADR-{序号}-{标题}.md`）+ 决策台账 `CONTEXT.md` |

### 2.2 五视角（指针）

细则 ∈ 各视角 **`*-meta.md` + README**；本文不复写。

| 视角 | meta / README | 层级（摘要） | 本层角色 |
| --- | --- | --- | --- |
| business | [business-meta](knowledge/business/business-meta.md) · [README](knowledge/business/README.md) | BD → BSD → BC → AGG → AB | 实现映射；BD 多为 ref |
| product | [product-meta](knowledge/product/product-meta.md) · [README](knowledge/product/README.md) | PL → PM → FT → FR → UC/BR（+ BP） | 实现映射；PL 多为 ref |
| application | [application-meta](knowledge/application/application-meta.md) · [README](knowledge/application/README.md) | SYS → APP → MS → **API** | **API SSOT** |
| data | [data-meta](knowledge/data/data-meta.md) · [README](knowledge/data/README.md) | MDG → DS → ENT → **TBL** | **TBL SSOT** |
| technical | [technical-meta](knowledge/technical/technical-meta.md) · [README](knowledge/technical/README.md) | TSD → **MW** → **CMP** | **MW/CMP SSOT** |

对照：[system/DESIGN.md](../system/DESIGN.md)、[company/DESIGN.md](../company/DESIGN.md)。

### 2.2.1 跨层实体首次定义层级

联邦三层**首次定义**层级如下；他处不重复字段语义。引用形态见 [knowledge-governance.md](../agent/knowledge/knowledge-governance.md)（有 parent 则 HTTP 到本表所列层的 SSOT 文件，否则纯 ID）。

| 视角 | 实体 | 首次定义层级 |
| --- | --- | --- |
| **业务** business | 业务域 BD | 公司 [company/](../company/DESIGN.md) |
| **业务** business | 业务能力 CAP | 公司 |
| **业务** business | 业务子域 BSD | 系统 [system/](../system/DESIGN.md) |
| **业务** business | 限界上下文 BC | 系统 |
| **业务** business | 聚合 AGG | 系统 |
| **业务** business | 能力 AB | 系统 |
| **产品** product | 产品线 PL | 公司 |
| **产品** product | 产品模块 PM | 系统 |
| **产品** product | 产品功能 FT | 系统 |
| **产品** product | 功能需求 FR | 系统 |
| **产品** product | 用户场景 UC | 系统 |
| **产品** product | 业务流程 BP | 系统 |
| **产品** product | 业务规则 BR | 系统 |
| **应用** application | 系统层 SYS | 公司 |
| **应用** application | 应用层 APP | 系统 |
| **应用** application | 模块层 MS | 系统 |
| **应用** application | 接口层 API | 应用（本层） |
| **数据** data | 主数据域 MDG | 公司 |
| **数据** data | 数据层 DS | 系统 |
| **数据** data | 实体 ENT | 系统 |
| **数据** data | 数据表 TBL | 应用（本层） |
| **技术** technical | 技术平台能力 TPL | 公司 |
| **技术** technical | 技术域 TSD | 系统 |
| **技术** technical | 中间件绑定 MW | 应用（本层） |
| **技术** technical | 组件 CMP | 应用（本层） |

### 2.3 阶段目录

约定 SSOT = 各目录 `README.md`（无 `*_meta.yaml`）。

| 阶段 | 要点 |
| --- | --- |
| **solutions** | 平铺 `SOLUTION-{IDEA-ID}.md`；`archive/` 归档；frontmatter：`id`，可选 `parent`/`dependencies` |
| **analysis** | 平铺 `ANALYSIS-{IDEA-ID}.md`；`parent` → Solution |
| **requirements** | `REQUIREMENT-{IDEA-ID}/MVP-Phase-*/`：PRD/ASD/DSD/TDD；详设正文仅 `DSD-*`；`spec-asd-*` 仅在 `specs/` |
| **changelogs** | `CHANGE-LOG.md`（docs-change）；`INDEXING-LOG.md`（docs-indexing） |

## 3. 核心映射（分布式引用）

源实体 frontmatter 写**目标实体 ID**。

| 方向 | 源 | 目标 | 字段 | 含义 |
| --- | --- | --- | --- | --- |
| 实现 | BC | APP | `implemented_by_app_id` | 上下文由哪个 APP 实现 |
| 实现 | AGG | MS | `implemented_by_service_ids` | 聚合根被哪些 MS 实现 |
| 实现 | AB | API | `apis`（`apis[].id`） | 能力绑定的 API |
| 需求支撑 | PM | BC | `relies_on_context_ids` | 模块依赖的上下文 |
| 接口 | FT | API | `invokes_api_ids` | 功能调用的 API |
| 接口 | UC | API | `map_to_api_id` | 用例映射的 API |
| 持久化 | AGG | ENT | `persisted_as_entity_ids` | 模型落哪些实体 |
| 归属 | ENT / DS | MS / APP | `owned_by_service_id` / `app_id` 等 | 写入与归属 |

## 4. ADR 与 ID 前缀

- **ADR**：`application/adr/ADR-{序号}-{标题}.md`；台账 `CONTEXT.md`；模板 [adr-template.md](../agent/knowledge/adr-template.md)；SDX 运行时 [sdx-adr-protocol.md](../agent/references/sdx-adr-protocol.md)
- **前缀**：BD、BSD、BC、AGG、AB、CAP、PL、PM、FT、UC、SYS、APP、MS、API、MDG、DS、ENT、TPL、TSD、MW、CMP — 全文 [naming-conventions.md](../agent/knowledge/naming-conventions.md)
