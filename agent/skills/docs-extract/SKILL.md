---
name: docs-extract
description: >
  从 `--sources` 按关键词命中提炼，去重后仅将 delta 写入 `--overview` 第三列（A/U/D）；细则 federation-spec。
  支持 `--dry-run`，不写 `DISTILL-LOG`。
  用户提到 /docs-extract、提炼进 overview、从设计文档整理进知识库、sources 写第三列时，使用本技能。
  分流：应用上行蒸馏 → docs-distill；overview 归档 → docs-archive；INDEX → docs-indexing；SDD → 对应技能。
  推进见 references/gates.md。
---

# docs-extract

## 输出硬约束（P0）

- 当前单元：单个 `--overview` 目标 + 单批命中段落。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得写入或输出正式预览结论；执行或预览后均须烤干，收敛后停等用户。
- `--dry-run`：三分区预览，不写第三列；无命中即结束单元。
- **第三列**：去重后仅写 delta；[federation-spec.md](../docs-distill/references/federation-spec.md)。
- **knowledge 引用边界**：写入 `*/knowledge/overview/**` 须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。可读 `--sources` 外源；落盘第三列不链源文件路径、不链下层/槽位、禁手写爬层。有 parent 则上层实体用生成函数 HTTP，否则纯 ID。违规能修则修，不明则停。

## 边界

- 负责：任意源 → overview 第三列；`A/U/D`；当前单元推进
- 不负责：docs-distill 上行 / `DISTILL-LOG`；docs-archive；docs-indexing；SDD 终稿

## 不这样用

- 不走前置草稿 + 集中收口；默认参数向导后「澄清 → 生成 → 烤干」
- 不把写前意图澄清当成完整 grilling Skill 深挖
- 不把本技能偷换成 `docs-distill`、`docs-archive` 或 `docs-indexing`

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 核心概念 | [core-concepts.md](references/core-concepts.md) |
| 提炼规范 | [extract-spec.md](references/extract-spec.md) |
| 原则 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |

## 最少输入

- 可解析的 `--sources`（路径或文本）
- 可解析的 `--overview`
- overview 内可读关键词附录
- 是否只做 `--dry-run`

## 产出

- 正式：`--overview` 第三列 `A/U/D`
- 预览：三分区 dry-run 摘要（将写入 / 跳过已覆盖 / 无命中）
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
