---
name: docs-distill
description: >
  将 application-{name}/ 已核实内容去重后以 delta 写入 overview 第三列；细则 federation-spec。overview 成功后追加 DISTILL-LOG。
  用户提到 /docs-distill、知识蒸馏、DISTILL-LOG、同步应用知识到系统 overview、更新系统库 overview、
  某应用知识库改了要同步、看看要同步哪些内容、系统库 overview 需要更新，
  或要把 application-* 已核实变更上行到系统库时，务必使用本技能。
  分流：任意源提炼 → docs-extract；overview 归档 → docs-archive；INDEX → docs-indexing；SDD → 对应技能。
  推进见 references/gates.md。
---

# docs-distill

## 输出硬约束（P0）

- 当前单元：单个 `{APPNAME}-overview.md` + 单次增量/全量预览范围。
- 写前澄清 / 推进环 `C/M/G/S/F` / 烤干 → [intent-clarify.md](../../references/intent-clarify.md)、[unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)、[grilling-skill.md](../../references/grilling-skill.md)、[docs-simplify.md](../../references/docs-simplify.md)；细节 [gates.md](references/gates.md)。未获写前 `C` 不得写入或输出正式预览结论；写入或 `--dry-run` 预览后均须烤干，收敛后停等用户。
- **原子性**：overview 第三列成功后才追加 `DISTILL-LOG`；失败禁止记日志。`--dry-run`：三分区预览，不写 overview / `DISTILL-LOG`。
- **第三列**：去重后仅写 delta；[federation-spec.md](references/federation-spec.md)。
- **knowledge 引用边界**：写入 `system/knowledge/**` 须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。可读槽位/应用外源；落盘 overview 不链外源路径、不链下层/槽位、禁手写爬层。有 parent 则上层实体用生成函数 HTTP，否则纯 ID。违规能修则修，不明则停。

## 边界

- 负责：已核实应用 → overview 第三列；增量/全量；`DISTILL-LOG`；当前单元推进
- 不负责：docs-extract；docs-archive；docs-indexing；SDD 终稿代写

## 不这样用

- 不走前置草稿 + 集中收口；默认参数向导后「澄清 → 生成 → 烤干」
- 不把写前意图澄清当成完整 grilling Skill 深挖
- 不把本技能偷换成 `docs-extract`、`docs-archive` 或 `docs-indexing`

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 推进 binding | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 受众与语言 | [audience-and-language.md](references/audience-and-language.md) |
| 核心概念 | [core-concepts.md](references/core-concepts.md) |
| 蒸馏规范 | [distill-spec.md](references/distill-spec.md)、[distill-log-spec.md](references/distill-log-spec.md) |
| 联邦规则 | [federation-spec.md](references/federation-spec.md) |
| 原则 / 反模式 | [design-principles.md](references/design-principles.md)、[anti-patterns.md](references/anti-patterns.md) |
| 终检 / 易错 | [quality-checklist.md](references/quality-checklist.md)、[gotchas.md](gotchas.md) |

## 最少输入

- 可定位的应用目录或 `--app`
- 可确定的增量起点：自动锚点或显式 `--since`
- 是否 `--full` / 是否只做 `--dry-run`
- `system/knowledge/overview/` 与 `system/changelogs/` 可写

## 产出与脚本

- 正式：`system/knowledge/overview/{APPNAME}-overview.md` 第三列
- 正式：`system/changelogs/DISTILL-LOG.md`（overview 成功后）
- 收敛后动作见 [unit-cycle-protocol.md](../../references/unit-cycle-protocol.md)（本技能有 `S`）

```bash
agent/skills/docs-distill/scripts/run-docs-distill.sh --help
```

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
