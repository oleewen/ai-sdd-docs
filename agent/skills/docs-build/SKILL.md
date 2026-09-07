---
name: docs-build
description: >
  从五视角提取实体 ID，产出 per-entity {ID}.md、各视角 README、扫描生成 KNOWLEDGE_INDEX.md；依赖主 Index Guide。
  用户提到 /docs-build、初始化/同步知识实体、对齐 ID、docs-indexing 下游要实体时，使用本技能。
  分流：仅 INDEX → docs-indexing；overview → distill/extract；归档 → docs-archive；SDD → 对应技能。
  推进见 references/gates.md。
---

# docs-build

## 输出硬约束（P0）

- 当前单元：单个视角批次、单个路径组，或单批实体集合。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得写 `{DOC_DIR}/knowledge/`；收敛后停等用户，不得自动推进下一批。
- 意图澄清第 6 项须写明当前批次及本轮 `{DOC_DIR}/knowledge/` 下仓库根相对路径（含 `{ID}.md`、README、`KNOWLEDGE_INDEX.md` 等）。
- 校验失败、路径不明或规则未覆盖时须停下澄清，不得静默继续。
- **knowledge 引用边界**：写入 `{DOC_DIR}/knowledge/**` 须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。可读外源；落盘不链 knowledge 外文档、不链下层/槽位、禁手写爬层。有 `knowledge-parent.yaml` 时上层实体用约定生成函数写 HTTP SSOT 链，否则纯 ID。违规能修则修，不明则停。

## 边界

- 负责：五视角 per-entity、README、`KNOWLEDGE_INDEX.md`、`validate-extraction.sh`
- 不负责：INDEX（docs-indexing）；OKF 迁移（docs-okf）；distill/extract；docs-archive；SDD

## 不这样用

- 不把写前意图澄清当成完整 grilling Skill 深挖
- 不把本技能偷换成 `docs-indexing`、overview、归档或 SDD 主路径

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 配置 / 规则 | [builtin-config.md](references/builtin-config.md)、[extraction-rules.md](references/extraction-rules.md) |
| README / 归并 | [readme-fill-spec.md](references/readme-fill-spec.md)、[consolidation-spec.md](references/consolidation-spec.md) |
| 核心概念 | [core-concepts.md](references/core-concepts.md) |
| 原则 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |

## 最少输入

- 主 Index Guide 可用
- `{DOC_DIR}` 可解析
- 可确定的视角范围
- `--skip-existing`、`--confidence-threshold`、`--emit-report` 等策略已收口

## 产出与脚本

- 正式：各视角 `{ID}.md`、README、`KNOWLEDGE_INDEX.md`
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

```bash
agent/skills/docs-build/scripts/validate-extraction.sh
```

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
