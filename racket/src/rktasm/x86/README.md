# rktasm/x86 — x86-64 后端（独立处理逻辑模块）

与 AArch64 管线并列、不共享实现（用户裁定 2026-10-20）；只沿用 directive 约定、
`regen.sh` 的 check/gate/regen 三分工与 C-oracle 差分 harness。规划与数据来源见
`../docs/x86-64-backend-plan.md`。

- `xed-convert.rkt <xed-checkout> <out.rktd>`：从 Intel XED datafiles 生成规范表
  （ICLASS/ISA_SET/EXTENSION/FLAGS/ATTRIBUTES/OPERANDS，PATTERN 原样保留供后置的编码器）。
