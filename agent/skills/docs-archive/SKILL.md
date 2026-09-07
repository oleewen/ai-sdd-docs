---
name: docs-archive
description: >
  将 overview 知识按表格行内副标题链接归档到 system/company 视角章节；
  先收口方案确认书，再按当前单元落目标章并按策略回写 overview。
  用户提到 /docs-archive、知识归档、overview 落盘、冲突检查、确认书归档时，使用本技能。
  分流：任意源提炼 → docs-extract；应用蒸馏 → docs-distill；实体/KNOWLEDGE_INDEX → docs-build；术语替换 → docs-upgrade；SDD → 对应技能。
  推进见 references/gates.md。
compatibility: Bash 5+；无专用校验脚本。
---

# docs-archive

## 输出硬约束（P0）

- 当前单元：单个目标章节，或单个 overview 行块。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得落盘或回写 overview；本技能默认必须烤干，收敛后停等用户。
- **确认书 = 意图澄清门禁**：批次级确认书收口即完成写前澄清；单元落盘前不再重复六项全清单，仅摘取本单元目标与路径。
- overview 回写须保留行内副标题链接；若改为索引壳，也不得承载新业务事实。
- **第三列 delta**：消费 extract/distill 的 A/U/D；`[D]` 按删除说明改目标章。回写后第三列 `—`。见 [federation-spec.md](../docs-distill/references/federation-spec.md)。
- **knowledge 引用边界**：写入 `*/knowledge/**` 须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。可读外源；落盘不链 knowledge 外文档、不链下层/槽位、禁手写爬层。有 parent 则上层实体用生成函数 HTTP，否则纯 ID。违规能修则修，不明则停。

## 边界

- 负责：overview → 链接指向的视角章节；确认书（意图澄清）；冲突检查；overview 按策略回写
- 不负责：docs-extract；docs-distill；docs-build；docs-upgrade；SDD 终稿

## 不这样用

- 不把写前意图澄清与确认书拆成两套停顿
- 不把写前步骤称作「写前 grilling」；`G` 仅写后深挖
- 不把本技能偷换成 `docs-build`、`docs-upgrade` 或 `docs-extract`

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 链接与索引 | [links-and-index.md](references/links-and-index.md) |
| 核心概念 | [core-concepts.md](references/core-concepts.md) |
| 原则 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |
| 确认书模板 | [archive-template.md](assets/archive-template.md) |

## 最少输入

- overview 来源路径或锚点
- 可解析的目标章节或 overview 行内链接
- 来源清理策略
- 初始冲突策略

## 产出

- 工作产物：当前确认书（含意图澄清六项）
- 正式：目标章节增补
- 正式：overview 按策略回写
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
