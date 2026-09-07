# docs-merge 常见陷阱

易与 [anti-patterns.md](references/anti-patterns.md) 对照；算法见 [merge-spec.md](references/merge-spec.md)。

## 参数

- 两路径都像 md / 用户语义可能相反 → 停问，勿默认第一源第二目标
- 路径不存在 → 先确认拼写；用户确认「就是正文」才当内联
- 单参 → candidate target，补收 source

## 落位

- 无标题块 → 必问挂靠节，禁止默默贴文末
- 多节同名 → 列含父级的全路径再选
- 「类似」吃不准 → 合并候选，勿当无关新增

## 写入 / knowledge

- 无写前六项 + 写前 C → 不写、不输出正式计划结论（dry-run 亦同）
- **未出变更清单即提问或落盘** / 未以提问逐项确认 / 未答完当前项即进下一项 → 禁止（见 merge-spec §5–§7）
- knowledge 库外链、爬层路径、无 parent 的跨层 HTTP → 落盘前按引用边界处理；不明则停

终检清单：[references/quality-checklist.md](references/quality-checklist.md)。
