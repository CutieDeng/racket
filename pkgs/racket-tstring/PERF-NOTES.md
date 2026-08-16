# tstring 输出性能笔记 (2026-08-07)

`f"..."` (物化整串) 与 `t"..."` (结构体 + 流式) 的输出性能取舍, 及与
`printf` 对齐的实测结论。触发问题: `(display f"...")` 先建整串再输出,
理论上多一次拷贝, 能否用 `t"..."` 流式避免?

## 已落地

- `render.rkt`: `write-template` — 把模板各段**直接流写端口**, 不物化整串;
  快路径: 无 format-spec/conversion 的 `{v}` → 直接 `(display value port)`
  (语义等同 `~a`, 省中间串, 精确对齐 `printf` 的 `~a`); 带 spec 才分配。
- `template.rkt`: `template-data` 挂 `prop:custom-write` (box 钩子破
  template↔render 模块环)。`(display t"...")` → 流式渲染;
  `(write t"...")` → 结构式 `#<template ...>` (调试)。
  **附带修正**: `write-template` honor format-spec, 而默认 `render-template`
  用 `~a` 忽略 spec——`write-template` 是更正确的行为。
- 回归测试 `tests/write-template-test.rkt` (流式==render、custom-write
  display/write 分流、spec honor、空插值), 全绿。

## 实测结论 (CS/Chez, 写 output-nowhere, 20 轮取最优, 运行时不透明值)

**初始假设被推翻**。按输出大小分两段 (交叉点 ~3 KB/次):

| 每次输出 | printf | f"" (string-append) | 融合流式 |
|--------:|:------:|:-------------------:|:--------:|
| 60 B    | 1.00×  | **0.35×** (最快)     | 0.90×    |
| 180 B   | 1.00×  | **0.39×**           | 0.92×    |
| 660 B   | 1.00×  | 0.68×               | 1.00×    |
| ~3 KB   | 1.00×  | 1.01× (交叉)         | **0.91×** |
| ~12 KB  | 1.00×  | 1.18× (变慢)         | **1.01×** |

关键事实:

1. **printf 的主导开销是每次调用重新解析格式串** (`~a` 扫描/分派), 不是
   IO。凡跳过解析的路径 (string-append / 融合写) 都 ≤ printf。
2. **小输出 (< ~3 KB): `f""` 的 string-append 最快** (0.35–0.68×)——一次
   小分配 + 一次写, 完胜。用户担心的"多一次拷贝"在此规模是净胜, 非净亏。
3. **大输出 (> ~3 KB): `f""` 退化** (1.18×)——O(输出长度) 的整串分配 + 拷贝
   变成真实成本 (用户的直觉在此规模成立); 流式直写保持平坦 ~1.0×。
4. **堆 template + custom-write 流式 (本次落地的 `(display t"...")`) 从不是
   最快**——它每次都分配 template + interpolation 结构体 (~1.6×)。它的价值
   在**易用性/正确性** (可 display、可 write 看结构、honor spec), 不在性能。

## 性能对齐 printf 的真正答案 (设计建议, 未落地)

不是运行时流式堆 template (反而多结构体开销), 而是**编译期融合输出宏**:
`(fdisplay [port] t"...")` 展开成内联 `(write-string lit port)(display val port)...`
序列——零 template 结构体、零输出串。它:
- 始终 ≤ printf (无格式重解析), 全尺寸 0.9–1.0× 平坦;
- 大输出下胜 `f""` (无整串分配);
- 小输出下略逊 `f""` string-append (0.9× vs 0.35×), 但换来无大输出悬崖。

即: **`f""` 是小输出默认最优 (日志行/短消息), 融合流式是大输出构建器
(报告/HTML/SQL 生成) 的专用工具**。落地需在 `expand.rkt` 加第三种展开模式
(parallel 于 expand-template/expand-fstring, 复用 parse-template-parts) +
一个 reader 前缀或宏形式——是独立语言面特性, 待决策。

## 矢量写 (rktio writev / write-bytes*) 对 t-string —— 实测否决 (2026-08-07)

沿"t"" 手里已是 slice 列表, 交 writev 一次写零拼接"的思路, 完整建成了
rktio 矢量写基础设施 (rktio_writev C 原语 → CS lock-object 零拷贝 pinning
→ 公开 `write-bytes*`, 见 racket/src/rktio/RKTIO-WRITEV-DESIGN.md)。建成后
实测三路对比: **write-bytes* 只在"少量大 slice"胜 (8×256KB 比 concat 快
275×), 而 t-string 的形态是"许多小段 + 小插值"——正是 writev 的弱区**
(300×1KB: concat 39ms 完胜 writev* 226ms, 因 300 次 lock-object pin 开销)。

**结论: t-string 不用 write-bytes*。** 原始直觉 ("多 slice 交 writev") 对
t-string 不成立——t-string 的小段多、单段小, per-slice 钉指针开销远超零拷贝
收益。回到本文件主结论: 小输出 f"" string-append 最优, 大单块输出融合流式;
矢量写留给"输出几个大 buffer"的非 t-string 场景。这是一次 measure-driven
的完整验证 (同 D1/SpecConstr/ccmp): 基础设施建成且正确, 但实测证明它不是
t-string 问题的答案。

## 性能规划收敛 (2026-08-07, f"" 余量实测后定稿)

沿"能否让 t-string 输出更快 / 对齐 printf"的规划逐条摸完, **结论收敛于
f"" 已是答案且近最优**:

1. **`(display f"...")` 已快于 printf** (前测: 小输出 f"" string-append 比
   printf 快 2-3×, 因 printf 每次重解析格式串)。原始"对齐 printf"目标不仅
   达到而且反超。
2. **"多一次拷贝"在 t-string 尺度是伪命题**: 小串一次分配+一次写胜过流式
   N 次分派 (write-bytes* 自适应实测: 多小 slice concat 完胜)。
3. **f"" 本身无有意义余量**: 对常见 `{v}`, 现状 `(format-fstring-value v #f "")`
   vs 直接 `(~a v)` 仅快 **1.05×** (5%, 被 ~a 字符串化+string-append 主导);
   为 5% 特殊化展开 (跳过 format-fstring-value) 不划算, 不做 (同 ccmp/SpecConstr
   的克制)。
4. **融合输出宏 / 矢量写**只在"少量大段"赢, 那是非 t-string 场景, 且已由
   通用自适应 write-bytes* 覆盖 (见 RKTIO-WRITEV-DESIGN.md)。

**最终建议: t-string 用 f"" (默认最优, 反超 printf, 近理论极限), 不再为
它做流式/融合/矢量的专门优化。** 少量大 buffer 输出用 write-bytes* (自适应)。
整条规划是 measure-driven 的完整闭环: 每个投机方向都建成/量化后, 用实测
把它归位到真实适用边界, 避免误配。
