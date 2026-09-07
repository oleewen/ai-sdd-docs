# agent/knowledge — 知识库治理 SSOT

本目录承载原 `*/constitution/` 迁移内容：术语、命名、原则与 ADR 约定。

- **三层边界**：[knowledge-governance.md](knowledge-governance.md)
- **协作闸门**：[CONVENTIONS.md](../rules/CONVENTIONS.md)
- **路径 / overview / 流水线**：[knowledge-layout.md](../references/knowledge-layout.md)
- **文件分型 / concept Profile**：[okf-spec.md](okf-spec.md)

## 组件

| 文件 | 说明 |
| --- | --- |
| [knowledge-governance.md](knowledge-governance.md) | 三层职责边界与业务 knowledge 引用边界 |
| [okf-spec.md](okf-spec.md) | company / system / application 共享知识规范 SSOT |
| [naming-conventions.md](naming-conventions.md) | 实体 ID 命名规范（全局 SSOT） |
| [glossary.md](glossary.md) | 全局术语表 |
| [architecture-principles.md](architecture-principles.md) | 架构原则条目 |
| [adr-template.md](adr-template.md) · [adr-guidelines.md](adr-guidelines.md) | ADR 模板与落盘约定 |
| [sdx-adr-protocol.md](../references/sdx-adr-protocol.md) | SDX 写 SOLUTION/ANALYSIS 时落 ADR / CONTEXT |
| [application/adr/](../../application/adr/README.md) · [system/adr/](../../system/adr/README.md) · [company/adr/](../../company/adr/README.md) | ADR 正文目录（按决策范围分域；含 `CONTEXT.md`） |

## 使用顺序

1. 新词 / 歧义 → [glossary.md](glossary.md)
2. 新实体 / 文件 → [naming-conventions.md](naming-conventions.md)
3. 判断文件是否 concept / 索引入口 / 叙事 / 元数据 → [okf-spec.md](okf-spec.md)
4. 跨域或长期后果的决策 → [application/adr/](../../application/adr/README.md) / [system/adr/](../../system/adr/README.md) / [company/adr/](../../company/adr/README.md)，按 [adr-template.md](adr-template.md)；SDX 流程见 [sdx-adr-protocol.md](../references/sdx-adr-protocol.md)

## 仓库地图

- 根：[INDEX-GUIDE.md](../../INDEX-GUIDE.md)、[index.md](../../index.md)、[AGENTS.md](../../AGENTS.md)
