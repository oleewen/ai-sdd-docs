---
name: docs-tag
description: >
  为 system/company overview 下 *-overview.md 做关键词相关度：候选词 → YAML 附录 → 表行 ✅ → 架构摘录（phase 3）。
  用户提到 /docs-tag、扫描关键词、给概览打标签、phase 3 时，使用本技能。
  分流：第三列提炼 / 全文术语 / INDEX → docs-extract、docs-upgrade、docs-indexing。
  推进见 light-flow-actions（C/M/S/F，无 G）与 references/gates.md。
---

# docs-tag

## 输出硬约束（P0）

- 当前单元：单个 overview 文件（phase 为单元内子阶段，非独立单元）。
- 轻流程：参数向导 → phase 执行 → 轻量校核 → `C/M/S/F`（无 `G`、不绑意图澄清 / 强制 grilling）→ [light-flow-actions.md](../../references/light-flow-actions.md)；细节 [gates.md](references/gates.md)。参数未收口前不得对 `--file` 写入。
- 每个 phase 结果后做轻量校核；当前单元未收敛前不得自动推进下一 overview。
- `--file` / `--phase` / `--keywords` / `--scan-dir` / `--top-n` / 是否续 phase 等语义项须先确认。
- `phase 3` / `excerpt` 不需 `keywords`；`phase 2` 无附录时不得静默继续，须提示先 `1-scan` + `1-write`。自动化禁用 `--phase 1`（见 gotchas）。
- **knowledge 引用边界**：写入 overview 须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」。摘录可读外源；落盘不链 knowledge 外文档、不链下层、禁手写爬层。有 parent 则上层实体用生成函数 HTTP，否则纯 ID。违规能修则修，不明则停。

## 边界

| 负责 | 不负责 |
| --- | --- |
| `--file`、`--phase`、附录、表行 ✅、架构摘录 | index；extract 第三列；upgrade 全库替换 |

## 不这样用

- 不把旧「步骤 1 参数确认」当唯一主线；主线是参数收口后处理当前单元
- 不把单个 phase 当成独立当前单元
- 不把第三列提炼、全库术语、INDEX 重建收成 `docs-tag`
- 不写成语义族「澄清 → 生成 → 烤干」

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 风险 | [workflow.md](references/workflow.md)、[gates.md](references/gates.md) |
| 轻流程动作 | [light-flow-actions.md](../../references/light-flow-actions.md) |
| 算法 | [algorithm.md](references/algorithm.md) |
| 易错 | [gotchas.md](gotchas.md) |

## 最少输入

- `--file`、`--phase`
- 若 phase 含 `1` 或 `all`，`--keywords`
- `--scan-dir`、`--top-n` 已展示默认或已收口

## 产出与脚本

- 正式：更新后的 overview（附录、表行、架构摘录）
- 收敛后动作见 [light-flow-actions.md](../../references/light-flow-actions.md)（本技能有 `S`，无 `G`）

```bash
python3 agent/skills/docs-tag/scripts/keyword_tag.py ...
```

单测：`python3 -m pytest tests/ -q`（技能目录下）。

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。重点：参数收口、单单元停顿、phase 后轻量校核、不得静默推进、不得要求语义族 grilling。
