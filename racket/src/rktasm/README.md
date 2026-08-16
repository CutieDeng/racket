# rktasm

一个用 Racket 编写的 ARM64 汇编编译器框架，支持 Lisp S-expression 语法编写 ARM64 汇编代码。

> **命名与来历**：rktasm 原名 **asmp**，2026-08 由独立仓
> `/Users/cutiedeng/Y2026/M05/D29/asmp.git`（feat/regalloc-scheduler 分支）
> 以工作树快照方式并入 racket 树（racket/src/rktasm，与 rktio/crypto/random
> 平级）；入树前的提交历史与 `.S` provenance 头里引用的 asmp commit 以原仓
> 为准。树内源码注释与文档中的 "asmp" 均指本组件。
>
> **构建独立性**：rktasm 是**开发期工具**，不进 racket 构建图——消费方
> （rktcrypto 等）提交装配产物 `.S`，构建只需 C 工具链；rktasm 仅在
> `regen`（再生内核）时被调用（见 `crypto/asm/regen.sh`，`RKTASM` 环境
> 变量可覆盖定位）。原仓的 `research/`、`example*/` 未随迁。

## 功能特性

- **Lisp 风格汇编语法**：使用 S-expression 编写 ARM64 汇编，代码更易读、易维护
- **完整编译管线**：解析 → 验证 → CFG 构建 → 寄存器分配 → 代码生成
- **虚拟寄存器支持**：自动进行图着色寄存器分配，支持溢出处理
- **多种 ABI 支持**：支持 `aapcs64`、`leaf`、`naked` 三种调用约定
- **双语法输出**：支持 GNU 和 Apple 汇编语法
- **ARM MRS 数据驱动**：基于 ARM 官方 Machine Readable Specification 自动生成指令编码
- **具名系统寄存器**：`mrs`/`msr` 支持具名 AArch64 系统寄存器操作数(如 `CNTVCTSS_EL0`),发射时翻成结构式 `Sx_x_Cx_Cx_x`(下游汇编器都认);寄存器表由 AARCHMRS `Registers.json` 生成

## 安装

### 依赖

- [Racket](https://racket-lang.org/) 编程环境

### 获取代码

```bash
git clone <repository-url>
cd asmp
```

无需额外安装依赖，所有必要的库已包含在 `vendor/` 目录中。

### 预编译（推荐）

首次运行前预编译可大幅提升启动速度：

```bash
# 编译主入口及其所有依赖
raco make cli/as.rkt
```

预编译后运行时间从数秒降至约 0.4 秒。

### 打包可执行文件

```bash
# 创建独立可执行文件
raco exe -o asmp cli/as.rkt

# 运行
./asmp example/001-basic.d
```

### 创建可分发包

生成可在无 Racket 环境的机器上运行的分发包：

```bash
raco exe -o asmp cli/as.rkt
raco distribute dist/ asmp
```

生成的 `dist/` 目录包含所有依赖，可直接复制到目标机器运行。

## 使用方法

### 基本用法

```bash
# 编译并输出到标准输出
racket cli/as.rkt example/001-basic.d

# 编译到文件
racket cli/as.rkt -o output.s example/001-basic.d

# 详细输出模式
racket cli/as.rkt -v example/001-basic.d
```

### 命令行选项

| 选项 | 说明 |
|------|------|
| `-o FILE` | 输出到文件 |
| `--stdout` | 输出到标准输出 |
| `-v`, `-vv`, `-vvv` | 详细程度 |
| `--gnu` / `--apple` | 选择汇编语法（默认 GNU） |
| `--stop-after=PHASE` | 在指定阶段停止（parse/validate/cfg/regalloc/emit） |
| `--dump=INFO` | 调试输出（ast/cfg/liveness/interference/allocation） |
| `-g`, `--debug-lines` | 生成源码行号和寄存器变量 DWARF 调试信息 |
| `--debug-reg-map` | 在输出汇编中追加虚拟寄存器分配映射注释 |
| `--cfi` | 生成调用帧展开信息，支持常见 `sp`/`fp` 栈帧 |
| `--default-abi=ABI` | 未指定调用 ABI 时的兼容默认值（aapcs64/leaf/naked/auto） |
| `--allow-spill` | 允许寄存器溢出 |
| `--no-verify-save-load` | 跳过 save/load 验证 |

### 运行测试

```bash
racket test/integration-test.rkt
racket test/parser-test.rkt
```

## 语法示例

### 基本指令

```lisp
;; 算术运算
(add x0 x0 x1)           ; x0 = x0 + x1
(sub x2 x0 1)            ; x2 = x0 - 1
(mul x3 x1 x2)           ; x3 = x1 * x2

;; 位移操作
(add x0 x0 x1 lsl 2)     ; x0 = x0 + (x1 << 2)

;; 比较与分支
(cmp x0 0)
(b.eq label_zero)
(b.ne label_nonzero)
```

### 内存访问

```lisp
;; 加载/存储
(ldr x0 (sp 0))          ; 从 [sp] 加载
(str x1 (x0 16))         ; 存储到 [x0 + 16]
(ldr x2 (x0 8 !))        ; 前索引：x0 += 8, 然后加载
(str x3 (x0) 8)          ; 后索引：存储，然后 x0 += 8
```

### 函数定义

```lisp
;; 默认 ABI
(: function my_add)
(: label entry)
    (add x0 x0 x1)
    (ret)
(: end-function)

;; 显式指定 ABI（在 function 行中声明）
(: function my_func (abi aapcs64))
(: label entry)
    (add x0 x0 x1)
    (ret)
(: end-function)

;; 叶函数 - 不调用其他函数，可优化
(: function leaf_func (abi leaf))
(: label entry)
    (madd x0 x0 x1 xzr)
    (ret)
(: end-function)

;; 裸函数 - 无自动 prologue/epilogue
(: function naked_func (abi naked))
(: label entry)
    ;; 手动管理栈帧
    (stp x29 x30 (sp -16 !))
    (mov x29 sp)
    ;; ...
    (ldp x29 x30 (sp))
    (add sp sp 16)
    (ret)
(: end-function)
```

### 函数属性

函数声明支持在 `(: function name ...)` 后添加属性：

```lisp
(: function my_func (abi aapcs64) (attr1) (attr2 value))
```

**已实现的属性：**

| 属性 | 说明 |
|------|------|
| `(abi <name>)` | 指定调用约定：`aapcs64`、`leaf`、`naked` |
| `(inline-only)` | 仅作为 inline 模板使用，不作为独立函数输出 |

**未实现的属性（仅解析，无实际功能）：**

解析器允许任意属性语法，但以下属性**当前未实现**，解析时会向 stderr
**告警并忽略**（GNU 前端的 `.clobber` 同理）：

- `(noinline)` - 无效果

这些属性作为语法预留存在，未来版本可能实现。

### 虚拟寄存器

```lisp
(: function example)
(: label entry)
    ;; 使用虚拟寄存器，编译器自动分配物理寄存器
    (mov x.temp x0)
    (add x.result x.temp x1)
    (mov x0 x.result)
    (ret)
(: end-function)
```

### 寄存器语法

| 语法 | 说明 |
|------|------|
| `x0-x30`, `w0-w30` | 通用寄存器 |
| `sp`, `zr` | 栈指针、零寄存器 |
| `v0-v31` | SIMD 向量寄存器 |
| `z0-z31` | SVE 向量寄存器 |
| `p0-p15` | SVE 谓词寄存器 |
| `x.name` | 虚拟寄存器 |

## 项目结构

```
asmp/
├── cli/                    # 命令行工具
│   ├── as.rkt              # 主汇编器入口
│   ├── parse.rkt           # 解析器 CLI
│   └── diagnose.rkt        # 诊断工具
├── parser/                 # 解析模块
│   ├── frontend.rkt        # 高层解析接口
│   ├── parser.rkt          # S-expression 解析器
│   └── ast.rkt             # AST 定义
├── syntax/                 # 语法验证
│   ├── validator.rkt       # 指令验证器
│   └── spec.rkt            # 指令规格
├── semantic/               # 语义分析
│   ├── control-flow.rkt    # 控制流图构建
│   └── use-def.rkt         # use-def 分析
├── pipeline/               # 编译管线
│   ├── pipeline.rkt        # 管线协调器
│   └── regalloc/           # 寄存器分配
├── codegen/                # 代码生成
│   └── emit.rkt            # ARM64 汇编输出
├── encode/                 # 指令编码
├── example/               # 示例代码
├── test/                   # 测试用例
└── ds/                     # 数据结构 (core 薄壳 + 宏单态化 omap 等)
```

持久化数据结构 (pvector/intmap/intbits/graph) 已全部使用 core 原生实现
（原 vendor cutie-ftree 于 2026-08-06 吸收清零）。

## 编译管线

```
源文件 (.d)
    ↓
1. PARSE      - S-expression → AST
    ↓
2. VALIDATE   - 语法/操作数验证
    ↓
3. CFG        - 控制流图构建
    ↓
4. SEMANTIC   - use-def / 分支分析
    ↓
5. REGALLOC   - 活性分析 → 干涉图 → 图着色分配
    ↓
6. REWRITE    - 虚拟寄存器 → 物理寄存器
    ↓
7. SAVE/LOAD  - 插入 callee-save/restore
    ↓
8. EMIT       - 生成 ARM64 汇编
    ↓
输出文件 (.s)
```

## 示例文件

| 文件 | 说明 | 运行命令 |
|------|------|----------|
| `example/001-basic.d` | 基本算术、立即数、位操作 | `racket cli/as.rkt example/001-basic.d` |
| `example/002-memory.d` | 内存加载/存储寻址模式 | `racket cli/as.rkt example/002-memory.d` |
| `example/003-branch.d` | 条件分支和循环 | `racket cli/as.rkt --no-verify-save-load example/003-branch.d` |
| `example/005-function.d` | 函数调用约定 | `racket cli/as.rkt --no-verify-save-load example/005-function.d` |
| `example/006-virtual-reg.d` | 虚拟寄存器和分配 | `racket cli/as.rkt --no-verify-save-load example/006-virtual-reg.d` |
| `example/007-abi.d` | ABI 声明 | `racket cli/as.rkt --default-abi aapcs64 example/007-abi.d` |

## License

[待补充]
