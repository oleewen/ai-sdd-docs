---
name: docs-okf
description: >
  OKF bundle refresh、校验与可视化：刷新 index.md、validate-okf、viz.html 与产物校验。
  须先读 .docsconfig：DOC_DIR→默认 bundle，KNOWLEDGE_TYPE→默认 viz；BUNDLE/--bundle 覆盖时 viz 跟随 bundle 目录名；无 config 或缺 KNOWLEDGE_TYPE 硬中止。
  用户提到 /docs-okf、OKF refresh、刷新 viz、DOC_DIR、DOC_ROOT、KNOWLEDGE_TYPE、目标工程 OKF 时，使用本技能。
  分流：用户只要 docs-build 提取或 docs-indexing 九章为主路径 → 对应技能。
  推进见 references/workflow.md。
---

# docs-okf

## 输出硬约束（P0）

- 无有效 `.docsconfig` 时立即中止；不得猜测 bundle 路径继续。
- 缺 `KNOWLEDGE_TYPE` 时立即中止；不得生成默认 `viz.html` 路径继续。
- `--dry-run` 只预览，不写盘。
- `validate` 出现 **ERROR** 时不得静默继续后续步骤；必须汇报错误并停下。
- 轻量运维技能：参数向导 → refresh / validate / viz → 结果摘要或失败分流；**不**引入当前单元循环或 `grilling` 协议。结果摘要出口须做受众 **A/B**（见 [audience-and-language.md](../../references/audience-and-language.md)、[light-flow-actions.md](../../references/light-flow-actions.md)）。
- **knowledge 引用边界**：刷新/改写 `*/knowledge/**` 索引或产物时须遵守 [knowledge-governance.md](../../knowledge/knowledge-governance.md)「业务 knowledge 引用边界」；不得引入爬层路径、下层链或 knowledge 外文档链。跨层 HTTP 仅能由约定生成函数写出。

## 边界

| 负责 | 不负责 |
| ------ | -------- |
| OKF refresh 编排、`index.md`、KNOWLEDGE_INDEX、validate-okf、viz、产物校验 | `INDEX-GUIDE.md`（docs-indexing）；新实体提取（docs-build）；SDD |

## 不这样用

- 不在无 `.docsconfig` 或缺 `KNOWLEDGE_TYPE` 时启发式猜路径继续
- 不把 validate ERROR 当 WARN 静默跳过
- 不把九章 INDEX 重建或实体提取收成 `docs-okf`
- 不引入意图澄清 / 单元循环 / grilling 作为本技能主线

## 路由

| 目的 | 文件 |
| --- | --- |
| 流程 / 参数 / 失败分流 | [workflow.md](references/workflow.md) |
| 路径解析 | [path-resolution.md](references/path-resolution.md) |
| 命名（OKF） | [naming-conventions.md](../../knowledge/naming-conventions.md) §OKF |
| 九章 INDEX（协作） | [docs-indexing/SKILL.md](../docs-indexing/SKILL.md) 产出节 |

## 最少输入

- 目标工程目录
- 有效 `.docsconfig`
- 可解析的 `KNOWLEDGE_TYPE`
- 模式：`refresh` / `validate` / `viz` / `dry-run`

## 产出与脚本

- 正式：刷新后的 bundle、`viz.html`、校验报告（参数见 [workflow.md](references/workflow.md)）

```bash
bash agent/skills/docs-okf/scripts/okf-indexing.sh [--dry-run]
bash agent/skills/docs-okf/scripts/okf-validate.sh [--bundle "${DOC_DIR}"]
```

## 评测

`evals/evals.json`、[grader.md](agents/grader.md)（P0 断言为准）。
