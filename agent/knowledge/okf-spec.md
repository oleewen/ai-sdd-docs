---
type: Knowledge Governance
title: OKF 共享规范
description: company、system、application 三层共享的知识文件分类与 OKF 概念实体规范。
tags: [okf, governance, shared-spec]
timestamp: "2026-06-25T00:00:00Z"
---
<!-- markdownlint-disable-next-line MD025 -->
# OKF 共享规范

> **谷歌 OKF v0.1 规范**：[`GoogleCloudPlatform/knowledge-catalog/okf/SPEC.md`](https://raw.githubusercontent.com/GoogleCloudPlatform/knowledge-catalog/main/okf/SPEC.md)
> **参考实现/讨论**：[github.com/google/open-knowledge-framework](https://github.com/google/open-knowledge-framework)
> **共享 SSOT**：本仓库 `agent/knowledge/okf-spec.md`
> **边界**：本文管**文件分型**与 **per-entity Profile**（frontmatter/正文/引用）。三层路径、overview 缓冲、联邦流水线 → [knowledge-layout.md](../references/knowledge-layout.md)；实体 ID 前缀 → [naming-conventions.md](naming-conventions.md)。
> **适用对象**：`company/`、`system/`、`application/` 三层知识库，以及围绕知识库组织的索引入口、叙事文档与元数据文件

---

## 规范总览

你要做的事只有一件：先分型，再写入。

- 先把文件分到 4 类之一：实体概念（per-entity）/ 索引入口 / 叙事文件 / 元数据（见 §1）。
- 只有“实体概念（per-entity）”才必须满足：frontmatter 10 字段必填 + 正文 4 段中文 H2（见 §2～§4）。
- 其他三类文件不按实体概念 Profile 处理：它们的首要目标是“导航/说明/契约/运维”，不是“稳定事实主定义”（见 §5～§7）。
- OKF Core 兼容原则：`type` 是 OKF 唯一必填字段；允许扩展字段（extensions）。本仓库对“实体概念”增加更强约束，但不否定 OKF Core（见 §0、§2）。
- 对应仓库文档分类矩阵时：实体概念、机器规约模板与被规则消费的规约样例默认按**机器规约类**处理，`frontmatter title` 属于契约字段，不得仅为消除 `MD025` 而删除。

快速判断：

| 问题 | 是 | 否 |
| --- | --- | --- |
| 这个文件描述的是“一个可被引用的对象”，且需要稳定 `full_id`？ | 实体概念（per-entity） | 继续判断 |
| 这个文件用于“从哪读/怎么读/怎么下钻/怎么枚举”？ | 索引入口 | 继续判断 |
| 这个文件用于“主题说明/架构叙事/综述/治理专题”？ | 叙事文件 | 元数据 |

## 0. 规范定位

本文是三层知识库的共享治理模板，主要面向 AI Agent（读/写/校验）。

目标（优先级从高到低）：

1. 降低误用：避免把 README/overview/meta 等文件当作实体概念写入与维护。
2. 统一预期：同一类文件在 company/system/application 三层保持一致的结构与职责边界。
3. 兼容 OKF：以 OKF v0.1 为 Core（`type` 必填、允许扩展字段），在此之上定义本仓库的实体概念（per-entity）Profile。

本文回答：

- 什么文件属于“实体概念（per-entity）”，什么文件属于“索引/叙事/元数据”？
- 不同类别文件分别必须满足哪些最小要求（MUST/SHOULD/MAY）？
- 三层目录如何复用同一套规则而不混写？

---

## 1. 文件分类方式

所有知识文件必须先分类，再决定是否按实体概念（per-entity）Profile 处理。

分型决策流程（建议按顺序）：

1. 先看用途：这是“对象事实”还是“导航/说明/契约/运维”？
2. 再看形态：是否需要稳定 `full_id` 作为跨文件引用主键？
3. 最后看落点：文件路径是否处于 `*/knowledge/<perspective>/...` 的实体树中？

说明：

- OKF Core 视角下：除 `index.md` / `log.md` 外，其他 `.md` 文件均可视为 concept（是否具备 frontmatter 与结构由生产者决定）。
- 本仓库治理视角下：为可维护性与检索稳定性，把 concept 再分为“实体概念（per-entity）”与“索引/叙事/元数据”等非实体文件。

### 1.1 实体概念（per-entity）

定义：

- 表示一个具有明确边界、唯一标识、可被其他文件引用的知识实体。
- 通常对应一个 `{ID}.md` 文件，并使用 `full_id` 作为稳定主键。

判断标准：

- 文件存在稳定 `full_id` 语义。
- 文件描述的是“一个对象”，而不是“一个目录如何阅读”或“一个主题总览”。
- 文件适合使用 `parent_id`、关系段和跨视角段表达结构。

典型文件：

- 模式：`{DOC_DIR}/knowledge/<perspective>/…/{ID}.md`（含父子同目录 `/{ID}/{ID}.md`）
- 路径根与视角目录见 [knowledge-layout.md](../references/knowledge-layout.md)；ID 前缀见 [naming-conventions.md](naming-conventions.md)
- EXAMPLE 样例树见各层 `knowledge/`（如 `*-EXAMPLE.md`），勿在本规范维护长路径清单

处理规则：

- 必须遵循本规范 §2-§10 的实体概念 Profile 规则。
- 必须包含中文 H2 的四段正文。
- frontmatter 必须包含 10 个必填字段；允许附加扩展字段（OKF extensions），但更推荐将业务属性下沉到正文。

### 1.2 索引入口

定义：

- 用于目录导航、阅读顺序、渐进披露、索引聚合的入口文件。

典型文件：

- `README.md`、各级 `index.md`、`knowledge/index.md`
- 各文档根 `INDEX-GUIDE.md`（路径见 [knowledge-layout.md](../references/knowledge-layout.md) / 九章约定）

处理规则：

- 不按实体概念 Profile 改造。
- 重点保证：
  - 当前目录说明清晰
  - 子目录/关键文件入口齐全
  - 与共享规范术语一致
  - 引用路径与下钻链路正确

### 1.3 叙事文件

定义：

- 面向主题、架构、综述、治理或专题说明的叙事型文件。

典型文件：

- `*-overview.md`
- `business-*.md`
- `product-*.md`
- `application-*.md`
- `data-*.md`
- `technical-*.md`

处理规则：

- 不强制按实体概念 Profile 处理。
- 重点保证：
  - 术语与实体概念一致
  - 引用实体路径正确
  - 叙事与索引链路不冲突

### 1.4 元数据

定义：

- 描述目录、规则、链接关系、日志或治理元信息的文件。

典型文件：

- `*-meta.md`
- `docs-meta.md`
- `knowledge-links.yaml`
- `CHANGE-LOG.md`
- `INDEXING-LOG.md`
- `DESIGN.md`

处理规则：

- 不按实体概念 Profile 改造。
- 重点保证其字段、职责与规范引用一致。

### 1.5 分型优先级

- 同时满足多类特征时，按以下优先级判断：
  - concept
  - 索引入口
  - 元数据
  - 叙事文件
- `README.md`、`index.md`、`index.md`、`index.md` 默认优先归为索引入口。
- `*-meta.md`、`docs-meta.md`、`knowledge-links.yaml`、变更日志默认优先归为元数据。

---

## 2. 实体概念 Profile：frontmatter（10 必填 + extensions）

本节定义实体概念（per-entity）的 frontmatter Profile。

- OKF Core：仅 `type` 为必填；允许任意扩展字段（extensions）。
- 本仓库 Profile：对实体概念要求 10 字段齐全，并约束 `type`/`hierarchy`/`layer_scope` 等一致性；同时允许扩展字段。

每个 per-entity 文件必须包含以下 10 个字段，并允许附加扩展字段（extensions）。同时，为了帮助读者理解当前 worktree 现状，下表也并列展示当前已观测到的非实体文档键。

| 分类 | 字段 | 类型 | 必填 | 说明 | 举例 |
| ------ | ------ | ------ | ------ | ------ | ------ |
| 核心键 + 观测键 | `type` | 枚举 | ✅（实体概念） / -（其他文档） | 对 per-entity 而言是 OKF Core 唯一必填字段；在其他文档中用于标识文件类别 | 实体概念：`Business Domain` / `API Endpoint` / `Component`；索引入口：`Documentation Root` / `Documentation` / `Agent Index Guide` / `Knowledge Index`；叙事文件：`Architecture Chapter` / `Architecture Overview Buffer`；元数据：`Directory Meta` / `Perspective Meta` / `Perspective Tree Meta` / `Change Log` / `Indexing Log` / `Requirement Package` / `Solution Document` / `Analysis Document` / `Design Document` / `Manifest` / `Contributing Guide` |
| 实体概念核心键 | `title` | 字符串 | ✅ | 中文名（实体显示名）；非实体文档中也广泛使用 | `计费业务域` / `应用知识库` |
| 实体概念核心键 | `description` | 字符串 \| null | ✅ | 业务定义短句；无定义时填 `null` | `统一管理主数据定义。` / `null` |
| 实体概念核心键 | `tags` | 字符串数组 | ✅ | per-entity 必含 `[<perspective>, <hierarchy>]`；其他文档可按用途扩展 | `[business, BD]` / `[okf, governance, shared-spec]` |
| 实体概念核心键 | `timestamp` | ISO8601 字符串 | ✅ | 形如 `2026-06-25T00:00:00Z` | `"2026-06-25T00:00:00Z"` |
| 实体概念核心键 | `full_id` | 字符串 | ✅ | 全局唯一 ID，格式：`<hierarchy>-<name>` | `BD-EXAMPLE` / `API-EXAMPLE-001` |
| 实体概念核心键 | `perspective` | 枚举 | ✅ | 与实体所属视角一致 | `business` / `product` / `application` / `data` / `technical` |
| 实体概念核心键 | `hierarchy` | 枚举 | ✅ | 与 `type` 一一对应 | `BD` / `CAP` / `PL` / `SYS` / `MDG` / `TPL` / `BSD` / `BC` / `AGG` / `AB` / `PM` / `BP` / `FT` / `UC` / `BR` / `APP` / `MS` / `DS` / `ENT` / `TSD` / `API` / `TBL` / `MW` / `CMP` |
| 实体概念核心键 | `parent_id` | 字符串 \| null | ✅ | 父层 full_id；BD 与 PL 允许 `null` | `BD-EXAMPLE` / `PM-EXAMPLE` / `null` |
| 实体概念核心键 | `layer_scope` | 枚举 | ✅ | 与知识库路径前缀对应 | `company` / `system` / `application` |
| 非实体文档键 | `okf_version` | 字符串 | - | 当前只出现在 bundle 根 `index.md` | `"0.1"` / `"1.0"` |
| 非实体文档键 | `status` | 字符串 | - | 当前只出现在公司层示例方案/分析文档 | `draft` / `"draft"` |

规则：

- 上述字段如仍有业务价值，推荐下沉到 `## 详细说明`、`## 关系` 或 `## 跨视角`，避免把“内容模型”固化进 frontmatter。
- 允许扩展字段（OKF extensions）。当某扩展字段成为“本仓库共享约定”（需要跨文件机器消费）时，必须更新本规范并写清语义与示例。

---

## 3. type 与 hierarchy 映射表

24 行精确映射。`type` 与 `hierarchy` 必须一一对应。

| hierarchy | type | perspective | 首次定义层 |
| ----------- | ------ | ------------- | ----------- |
| BD | `Business Domain` | business | company |
| CAP | `Business Capability` | business | company |
| PL | `Product Line` | product | company |
| SYS | `System` | application | company |
| MDG | `Master Data Domain` | data | company |
| TPL | `Technical Platform` | technical | company |
| BSD | `Business Subdomain` | business | system |
| BC | `Bounded Context` | business | system |
| AGG | `Aggregate` | business | system |
| AB | `Ability` | business | system |
| PM | `Product Module` | product | system |
| BP | `Business Process` | product | system |
| FT | `Feature` | product | system |
| UC | `Use Case` | product | system |
| BR | `Business Rule` | product | system |
| APP | `Application` | application | system |
| MS | `Microservice` | application | system |
| DS | `Data Store` | data | system |
| ENT | `Entity` | data | system |
| TSD | `Technical Subdomain` | technical | system |
| API | `API Endpoint` | application | application |
| TBL | `Data Table` | data | application |
| MW | `Middleware Binding` | technical | application |
| CMP | `Component` | technical | application |

说明：

- “首次定义层”表示该概念的治理语义与模板首次出现在哪一层。
- 下游层允许做投影、实例登记、实现映射或物理锚点，不等于“只允许在该层出现”。

---

## 4. per-entity 四段正文结构（实体概念 Profile）

### 三层实证要点（per-entity）

MUST：

- 文件为 `{ID}.md` 且在三层 `*/knowledge/<perspective>/...` 下，可被其他文件以链接引用。
- frontmatter 满足实体概念 Profile 的 10 字段必填（见 §2），并保持 `type`/`hierarchy`/`perspective`/`layer_scope` 一致。
- 正文包含 4 个中文 H2（见本节），用于承载关系、跨视角、说明与证据。
- 关系与跨视角引用使用可解析链接；同一文件内链接风格保持一致。
- 业务三层 `*/knowledge/**` 的跨文件引用方向与形态遵守 [knowledge-governance.md](knowledge-governance.md)「业务 knowledge 引用边界」（同层 bundle-relative；向上有 parent 则 HTTP 到首次定义层 SSOT，无 parent 则纯 ID；禁下层/槽位/爬层；依据段不链库外文档路径）。

SHOULD：

- `description` 保持“一句话可复述”的短句；更长说明放 `## 详细说明`。
- 知识内证据优先用同层 bundle-relative 链，或上层首次定义层 HTTP（有 `knowledge-parent.yaml`）/ 纯 ID（无 parent）；库外证据用 URI/资产名（见治理边界），变更时同步。
- 扩展字段（OKF extensions）仅用于“确需机器消费且跨文件共享”的字段；否则下沉到正文以降低耦合。

MAY：

- 添加 `resource`（OKF 推荐字段）指向底层资产（代码仓、表、接口、工单等）的 canonical URI（非库外文档相对路径）。
- 添加少量扩展字段（OKF extensions）以支持自动化生成/索引，但必须在团队约定下长期维护。

代表性文件：

- 落点模式见 [knowledge-layout.md](../references/knowledge-layout.md)；EXAMPLE 见各层 `knowledge/` 样例树
- ID / type 映射见 [naming-conventions.md](naming-conventions.md) 与本文 §3

每个 per-entity 文件必须包含 4 个二级标题，标题统一使用中文：

| 顺序 | 标题 | 内容 |
| ------ | ------ | ------ |
| 1 | `## 关系` | 父子、聚合、能力、应用实现等结构关系 |
| 2 | `## 跨视角` | 跨 perspective 引用 |
| 3 | `## 详细说明` | 业务定义、职责、不变量、验收标准等 |
| 4 | `## 依据与证据` | 同层链、上层 SSOT HTTP 或纯 ID；或外部 URI/资产名（见 [knowledge-governance.md](knowledge-governance.md)） |

### 4.1 关系段

按层级差异化：

| 层级 | 必含子段 | 选含子段 |
| ------ | --------- | --------- |
| BD | `parent: null` + `children: [...]` | — |
| BSD | `parent: [...]` + `bounded_contexts: [...]` | — |
| BC | `parent: [...]` + `aggregates: [...]` | — |
| AGG | `parent: [...]` + `abilities: [...]` | — |
| AB | `parent: [...]` + `implemented_by_app_id: [...]`（允许 `(none)`） | — |
| PL | `children: [...]` | `parent: null` |
| PM | `parent: [...]` + `children: [...]` | — |
| FT | `parent: [...]` + `children: [...]` | — |
| UC | `parent: [...]` | — |
| APP | `parent: [...]` + `service_ids: [...]` | — |
| SYS | `children: [...]` | `parent: null` |
| DS | `parent: [...]` 或 `(none)` | — |
| ENT | `parent: [...]` | — |
| TSD | `children: [...]` | — |
| MW | `parent_tsd_id: [...]` 或 `(none)` | — |
| CMP | `(none)` 或 `parent_mw_id: [...]` | `parent_app_id: [...]` |

指针格式：

- 同目录：`[X-XXX](X-XXX.md)` 或 `[X-XXX](X-XXX/X-XXX.md)`
- 跨 perspective（同 bundle）：`[X-XXX](../../<other-perspective>/X-XXX/X-XXX.md)` 或 `/knowledge/...`
- 跨层：遵守 [knowledge-governance.md](knowledge-governance.md)（生成函数 HTTP 或纯 ID）；禁止手写跨 `DOC_DIR` 相对路径。

### 4.2 跨视角段

- 跨 perspective 引用可按 `business:` / `product:` / `application:` / `data:` / `technical:` 子段组织。
- 无引用时填 `(none)`。
- 禁止在跨视角段内引用同 perspective 实体；同 perspective 关系应写在 `## 关系`。

### 4.3 详细说明段

允许包含：

- 业务定义 / 关键职责 / 关键不变量
- 关键 ADR 摘要
- 通用语言列表
- 根实体 / API 列表 / 目标用户 / 验收标准
- 原 frontmatter 中下沉的业务属性

无内容时填 `(none)`。

### 4.4 依据与证据段

- 使用文件路径 + 章节锚点
- 多源用换行或分号串接
- 无额外来源时可保留 `示例数据`

---

## 5. 索引入口处理规则

适用于：

- `README.md`
- `INDEX-GUIDE.md`（九章索引指南；仅仓库根或各 DOC_DIR 根）
- `index.md`（bundle 根与子目录的 OKF 渐进披露/目录索引入口）
- `index.md`（OKF 渐进披露入口：bundle 子目录）
- `knowledge/index.md`（知识实体扫描索引）

MUST：

- 目录说明清晰
- 当前目录关键文件与子目录入口齐全
- 与 concept、叙事、元数据分型保持一致
- 不强行加入 concept frontmatter
- OKF 渐进披露入口（bundle 根 `index.md` 的 OKF 区块）仅允许 `okf_version` 作为 frontmatter

SHOULD：

- `README.md`：人类入口
- `index.md`：当前目录渐进披露（bundle 根为 OKF 区块 + 目录索引；子目录为渐进披露入口）
- `<DOC_DIR>/INDEX-GUIDE.md`：九章机器索引（仓库根或各 DOC_DIR）
- `knowledge/index.md`：知识实体扫描索引

MAY：

- 在索引入口中加入“常见问题/反例”（例如：哪些文件不应按实体概念写），用于降低误用率。

代表性文件：

- 人类入口 / 渐进披露 / 九章地图：见各 `{DOC_DIR}/README.md`、`index.md`、`INDEX-GUIDE.md`（布局见 [knowledge-layout.md](../references/knowledge-layout.md)）
- 知识实体扫描索引：`{DOC_DIR}/knowledge/index.md`

---

## 6. 叙事文件处理规则

适用于：

- `*-overview.md`
- `business-*.md`
- `product-*.md`
- `application-*.md`
- `data-*.md`
- `technical-*.md`

MUST：

- 保持其“主题说明/架构叙事”角色
- 不伪装成 concept
- 若引用概念实体，应使用稳定路径与术语
- 术语应与本规范和实体文件一致

SHOULD：

- 采用结构化 Markdown（标题、表格、列表）提升检索与可维护性。
- overview 类文档按“主标题/副标题/归档列”结构稳定维护，便于 docs-tag/docs-archive/docs-extract 联动。
- **路径、行序、第三列技能落点**以 [knowledge-layout.md](../references/knowledge-layout.md) 为准；本文只定「叙事/非 concept」分型。

MAY：

- 使用 HTML 注释给出写作提示与产出建议（用于模板/占位），但不影响正文可读性。

代表性文件：

- overview 缓冲与章节叙事路径见 [knowledge-layout.md](../references/knowledge-layout.md)
- 治理叙事型设计摘录：各层 `DESIGN.md`（非 per-entity）

---

## 7. 元数据文件处理规则

适用于：

- `*-meta.md`
- `docs-meta.md`
- `knowledge-links.yaml`
- `CHANGE-LOG.md`
- `INDEXING-LOG.md`
- `DESIGN.md`

MUST：

- 保持规则、目录元信息、链接编排或运维日志职责
- 不按 concept schema 改造
- 引用规范路径时统一指向本文件

SHOULD：

- 在 meta 内说明“哪些字段为约定/枚举、哪些为解释性文字”，避免把可变叙事塞进结构字段。
- 变更留痕与索引运维文件遵循各自目录 README 的约定，避免在多个地方定义同一条运维规则。

MAY：

- 增加面向工具链的附加字段（OKF extensions），用于自动化生成/校验/索引，但需保证长期维护成本可控。

代表性文件：

- 模式：`{DOC_DIR}/docs-meta.md`、`{DOC_DIR}/knowledge/knowledge-meta.md`、`{DOC_DIR}/knowledge/<perspective>/*-meta.md`
- 联邦链接：`{DOC_DIR}/knowledge-links.yaml`（路径语义见 [knowledge-layout.md](../references/knowledge-layout.md)）
- 运维日志：`CHANGE-LOG.md` / `INDEXING-LOG.md`（落在约定 `changelogs/`）

---

## 8. 目录哲学

### 8.1 父子同目录可见

对于有下层概念的目录，父子实体应尽量在同一父层目录下肉眼可见（如 `BSD-{ID}/` 下同时可见 `BSD-{ID}.md` 与子概念 `{ID}.md`）。完整树形与落点见 [knowledge-layout.md](../references/knowledge-layout.md)、[naming-conventions.md](naming-conventions.md)。

### 8.2 父层目录的 `index.md`

每个含子概念目录必须提供 `index.md` 罗列子概念（OKF Concepts 列表）；样例见各层 `knowledge/` EXAMPLE 树，勿在本规范维护长清单。
---

## 9. 跨视角引用规则

| 引用类型 | 位置 | 形式 |
| --------- | ------ | ------ |
| 父子 / 聚合 / 能力 | `## 关系` | `parent:` / `children:` / `aggregates:` / `abilities:` |
| 应用实现 | `## 关系` | `implemented_by_app_id:` |
| 跨 perspective | `## 跨视角` | `business:` / `product:` / `application:` / `data:` / `technical:` |
| 证据来源 | `## 依据与证据` | 路径 + 锚点 |

补充规则：

- 同 perspective 内引用优先走 `## 关系`
- 跨层但同实体的“上游主定义”说明优先放在 `## 详细说明`
- 不要求在 frontmatter 中表达跨视角链路

---

## 10. company / system / application 三层共享模板

### 10.1 company

- 重点概念：`BD / CAP / PL / SYS / MDG / TPL`
- 文件组成以 company 级概念实体 + 治理叙事 + 系统槽位为主
- 叙事和元数据占比高，必须严格区分 concept 与非 concept

### 10.2 system

- 重点概念：`BSD / BC / AGG / AB / PM / BP / FT / UC / BR / APP / MS / DS / ENT / TSD`
- 既有丰富 example，又有更复杂的叙事与目录组织
- 是 company 语义向 application 实现映射的中间层

### 10.3 application

- 重点概念：`API / TBL / MW / CMP`
- 也承接上游 concept 的投影与实现细节
- 对物理锚点、宿主信息与配置证据要求更高

---

## 11. 校验与演进

### 11.1 layer_scope 规则

| layer_scope | 文件路径前缀 |
| ------------- | ------------- |
| `company` | `company/knowledge/...` |
| `system` | `system/knowledge/...` |
| `application` | `application/knowledge/...` |

### 11.2 tags 与 timestamp

- `tags` 必含 `[<perspective>, <hierarchy>]`
- `timestamp` 使用 ISO8601 UTC 格式：`YYYY-MM-DDTHH:MM:SSZ`

### 11.3 演进

- 不破坏兼容性的增量修改，在本规范末尾追加附录。
- 不兼容变更另起新版本文件，例如 `okf-spec-v2.md`。
- 允许扩展字段；但当扩展字段成为“本仓库共享约定”时，不允许静默新增，必须同步更新本规范。

### 11.4 删除旧规范约束

- 旧 system 下 schema 规范删除后，本文件为唯一 SSOT。
- 仓库内不应再出现对旧路径的引用。
