---
name: docs-upgrade
description: >
  定向改 Markdown、注释、配置文本；统一术语并沿引用链 + 关键词链式同步。
  用户提到 /docs-upgrade、改文档、统一术语、把 X 换成 Y，或简写 a - b / a > b / a 2 b（均为 a→b）时，使用本技能。
  分流：用户只要 docs-archive/change/indexing/build 或仅 CHANGE-LOG/INDEX → 对应技能；结构精简/SSOT 去重 → docs-simplify。
  推进见 references/gates.md。
---

# docs-upgrade

## 输出硬约束（P0）

- 当前单元：单个主文件，或单个已确认关联批次。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得写入或扩展关联；写入后须烤干，收敛后停等用户。
- 用户明示「只改本文件 / 不要关联 / 不要全库搜」时，不得静默重开链式扩展。
- **knowledge 引用边界**：改写 `application|system|company` 下 `*/knowledge/**` 时须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。替换/同步不得引入 knowledge 外文档链、下层链或手写爬层；跨层 HTTP 仅生成函数，无 parent 则纯 ID。违规能修则修，不明则停。

## 边界

| 负责 | 不负责 |
| ---- | ------ |
| MD/注释/配置文档性文本；引用链 + 关键词；意图澄清与范围收口；当前单元推进 | docs-change、docs-indexing、docs-archive、docs-build、docs-simplify 主流程 |

## 不这样用

- 不走「范围确认后直接写、跳过意图澄清」的旧主线；默认参数向导后「澄清 → 生成 → 烤干」
- 不在用户已限定“只改本文件”时强制扩展整条引用链
- 不把 CHANGE-LOG 聚合、INDEX 重建、overview 行归档、实体索引主路径收成 `docs-upgrade`
- 不把写前意图澄清称作 grilling；`G` 仅写后深挖

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 范围模板 | [docs-upgrade-scope-ack-template.md](assets/docs-upgrade-scope-ack-template.md) |
| 关联发现 | [related-doc-discovery.md](references/related-doc-discovery.md)、[semantic-keyword-discovery.md](references/semantic-keyword-discovery.md) |
| 原则 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |

## 最少输入

- 主目标文件或可确认的候选范围
- 改动摘要或术语替换目标
- 是否允许关联扩展已收口
- 若涉及术语或路径迁移，语义边界已确认

## 产出

- 正式：已改主文件与已确认关联；链校验见 [quality-checklist.md](references/quality-checklist.md)
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
