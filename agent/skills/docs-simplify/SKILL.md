---
name: docs-simplify
description: >
  就地优化 Markdown：金字塔结构、激进精简、SSOT 去重改引用。
  用户提到 /docs-simplify、精简文档、去啰嗦、金字塔、去重引用、结构化改写、压缩正文时，使用本技能。
  分流：术语统一 → docs-upgrade；INDEX/CHANGE-LOG/归档/实体主路径 → 对应技能。
  写作原则 SSOT：[agent/references/docs-simplify.md](../../references/docs-simplify.md)。推进见 references/gates.md。
---

# docs-simplify

## 输出硬约束（P0）

- 当前单元：单个主文件，或单个已确认扩批。
- 原则：[docs-simplify.md](../../references/docs-simplify.md)（A 结构 / B 简明 / C 真源）。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得写入或扩批；写入后须烤干，收敛后停等用户。
- 默认排除 `INDEX-GUIDE.md` / `index.md` / 扫描生成物 / `changelogs/`；**用户点名则照改**。
- 疑似 SSOT 重复：全仓语义相似可扫，**未确认不得**改成链接或删段。
- 模板硬结构（SDD 固定章、编号表）：主砍散文，不拆章刷短；表密文档不以行数 KPI 判失败。见 [docs-simplify.md](../../references/docs-simplify.md)「模板硬结构」。
- **knowledge 引用边界**：改写 `application|system|company` 下 `*/knowledge/**` 时须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。去重改引用不得链出 knowledge 外 / 下层 / 爬层；跨层 HTTP 仅生成函数，无 parent 则纯 ID。违规能修则修，不明则停。

## 边界

| 负责 | 不负责 |
| ---- | ------ |
| 点名 MD 的结构重组、激进精简、去重改引用；意图澄清与范围收口 | 术语链式替换（docs-upgrade）；INDEX/CHANGE-LOG/归档/实体索引主流程 |

## 不这样用

- 不跳过意图澄清直接改写
- 不在用户未确认时静默扩批第二份文件
- 不把术语统一主路径收成本技能
- 不把写前意图澄清称作 grilling；`G` 仅写后深挖
- 不砍约束 / 例外 / 验收条件

## 路由

| 目的 | 文件 |
| --- | --- |
| 原则 SSOT | [docs-simplify.md](../../references/docs-simplify.md) |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 范围模板 | [docs-simplify-scope-ack-template.md](assets/docs-simplify-scope-ack-template.md) |
| 原则摘要 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |

## 最少输入

- 主目标文件（或可确认的候选）
- 是否允许扩批 / 是否包含默认排除类文件
- 精简力度确认（默认激进，约束必留）

## 产出

- 正式：已改主文件（及已确认扩批）；清单见 [quality-checklist.md](references/quality-checklist.md)
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
