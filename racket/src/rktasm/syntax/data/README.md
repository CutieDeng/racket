# syntax/data 数据文件说明

## 目录结构

```
syntax/data/
├── generated/                    # 核心数据 (从 MRS 提取，不可派生)
│   └── instruction-spec.rktd     # 指令规范 - 唯一核心文件
│
├── cached/                       # 派生数据 (可从 generated 重建)
│   ├── index-mnemonic.rktd       # 按助记符索引
│   ├── index-layer1.rktd         # Layer1 类索引
│   ├── index-layer2.rktd         # Layer2 签名索引
│   └── integrated-table.rktd     # 整合查找表
│
└── README.md                     # 本文件
```

## 数据关系

```
instruction-spec.rktd (核心)
    │
    │  encoding → (mnemonic, template, constraints)
    │
    ├──→ template ──→ Layer2 签名  (parse-template-signature 计算)
    │                    │
    │                    └──→ Layer1 类  (layer2->layer1 计算)
    │
    └──→ constraints ──→ Layer3 约束 (直接存储)
```

## 文件格式

### generated/instruction-spec.rktd

唯一的核心数据文件，包含从 MRS JSON 提取的完整指令规范。

```scheme
;; 格式: (encoding-id mnemonic template ((field constraint) ...))

("ADD_64_addsub_shift" add "XZR, XZR, XZR, LSL, UInteger"
  (("Rd" (reg-range 0 31))
   ("Rn" (reg-range 0 31))
   ("Rm" (reg-range 0 31))
   ("imm6" (imm-range 0 63 1))))

("LDR_64_ldst_pos" ldr "XZR, [SP UInteger]"
  (("Rt" (reg-range 0 31))
   ("Rn" (reg-range 0 31))
   ("imm12" (imm-range 0 4095 1))))
```

### cached/index-layer1.rktd

助记符到 Layer1 类的索引。

```scheme
;; 格式: (mnemonic (layer1-class ...))

(add (c2 c3 c4 c5))
(ldr (c1m c2m))
(ret (c0))
```

### cached/index-layer2.rktd

(助记符, Layer1类) 到 Layer2 签名的索引。

```scheme
;; 格式: ((mnemonic layer1-class) (signature ...))

((add c3) ((gpr-64 gpr-64 immediate) (simd-vector simd-vector simd-vector)))
((ldr c1m) ((gpr-64 memory) (gpr-32 memory)))
```

### cached/integrated-table.rktd

完整的层级查找表，用于验证时快速查找。

```scheme
;; 格式: (mnemonic (layer1 (layer2-sig (encoding ...) ...) ...) ...)

(add
  (c3
    ((gpr-64 gpr-64 immediate)
      ("ADD_64_addsub_imm" "SP, SP, UInteger" (...))
    )
    ((simd-vector simd-vector simd-vector)
      ("ADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (...))
    )
  )
)
```

## 生成命令

### 从 MRS 生成核心数据

```bash
# 生成 instruction-spec.rktd (唯一核心文件)
racket syntax/gen-instruction-spec.rkt

# 可选参数:
#   -j <path>  指定 Instructions.json 路径
#   -o <path>  指定输出文件路径
```

### 重建缓存文件

```bash
# 从 instruction-spec.rktd 重建所有缓存
racket syntax/gen-cached.rkt

# 可选参数:
#   -s <path>  指定 instruction-spec.rktd 路径
#   -c <dir>   指定缓存输出目录
```

### 完整重建流程

```bash
# 1. 从 MRS JSON 提取核心数据
racket syntax/gen-instruction-spec.rkt

# 2. 重建所有缓存
racket syntax/gen-cached.rkt
```

## Layer 计算规则

### Layer2 签名 (从模板计算)

模板字符串通过 `parse-template-signature` 解析为类型签名：

```
"XZR, XZR, XZR"         → (gpr-64 gpr-64 gpr-64)
"VUInteger.8B, [SP]"    → (simd-vector memory)
"ZUInteger.B, PUInteger/M, ZUInteger.B" → (sve-z sve-p sve-z)
```

### Layer1 类 (从 Layer2 计算)

Layer2 签名通过 `layer2->layer1` 计算结构类：

```
(gpr-64 gpr-64 gpr-64)           → c3     (3个操作数)
(gpr-64 memory)                   → c1m    (1个操作数+内存)
(gpr-64 gpr-64 memory immediate)  → c2m1   (2个+内存+1后)
```

计算规则：
1. 找到 `memory` 类型的位置 (如果有)
2. `pre` = memory 之前的操作数数量 (或总数)
3. `post` = memory 之后的操作数数量
4. 类名 = `c{pre}[m[{post}]]`

## 统计

- 总编码数: 4349
- 助记符数: 1527
- Layer1 类: 13 种
- Layer2 签名: ~200 种
- Layer3 约束类型: 6 种

## 旧文件迁移

以下旧文件可以删除 (数据已整合到新结构):

```
syntax/data/instruction-variants.rktd    → 整合到 instruction-spec.rktd
syntax/data/variant-class.rktd           → 可计算
syntax/data/template-signature.rktd      → 可计算
syntax/data/instruction-constraints.rktd → 整合到 instruction-spec.rktd
syntax/data/syntax-class-db.rktd         → 整合到 index-layer1.rktd
syntax/data/index-layer1.rktd (旧)       → 移到 cached/
syntax/data/index-layer2.rktd (旧)       → 移到 cached/
syntax/data/index-layer3.rktd            → 不再需要
syntax/data/integrated-table.rktd (旧)   → 移到 cached/
syntax/data/instruction-layer2-map.rktd  → 调试用，可删除
syntax/data/instruction-signatures.rktd  → 调试用，可删除
syntax/data/layer2-types.rktd            → 文档，可保留
syntax/data/layer3-types.rktd            → 文档，可保留
syntax/data/layer3-summary.rktd          → 调试用，可删除
```
