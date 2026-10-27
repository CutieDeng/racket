# .zo 代码 vfasl 的 bundle 级合并 — 实施规格(逐模块分解)

2026-10-07 · 承接 `repl-startup-forward-design.md` §7.5b(M2-步3 per-linklet .zo-vfasl 已落地,f1ce780e71)。
目标:把"每 linklet 一个 vfasl 镜像"改成"每 bundle 的启动期需求集一个镜像",消掉每镜像固定成本。

## 0. 结论与数字

### 0.1 本次实测(树内 collects .zo,`racket -e '(void)'` = 默认 init 库 racket/init)

| 项 | 值 | 来源 |
|---|---|---|
| 启动期解码 bundle | 337 | `PLT_LINKLET_TIMES` read-bundle 次数 |
| 启动期 eval 的 linklet(= 现 vfasl 镜像数) | 1679,8MB | faslin-code 次数/字节 |
| 启动期 instantiate 分类 | decl 337 / data 337 / stx 368 / stx-data 255 / 模块体 ~228 | `PLT_LINKLET_TRACE_TIMES` instance 名分类 |
| 静态:闭包 310 文件 → 623 bundle | class-A(decl,data,stx,stx-data,0)=2399 linklet 7.38MB;class-B(phase≥1)=252 linklet 2.57MB | `zo-stats.rkt`(scratchpad) |
| class-A 每 bundle 成员数 | 3 个(358 bundle)或 5 个(265 bundle),无其他 | 同上 |
| class-A 每 bundle 字节分布 | 1-4KB:327,4-16KB:182,16-64KB:91,64-256KB:22,>256KB:1 | 同上 |
| 'interpret 格式 linklet | 7 | 同上(不参与合并) |

**已验证**:启动期需求集 = class-A 全集(decl+data+stx+stx-data+phase0),phase≥1 在提示符前不被 eval。
→ 合并粒度定为"每 bundle 的 class-A 一个镜像":1679 镜像 → 337 镜像;class-B 不动(v2 可选)。

### 0.2 预期(推断,待 G1 门禁实测)

- 每镜像固定成本 ≈ 9.5µs(由 §7.5b 数据反推:per-linklet 16.5ms − 单大镜像变动部分 4.2ms = 12.3ms / 1294)。
- faslin-code:per-linklet vfasl ≈ 20ms(当前闭包)→ 合并 ≈ 4.2 + 337×9.5µs ≈ 7.5ms;faslin-literals 调用 1679→337。
- 端到端:相对 per-linklet vfasl −10~−15ms;相对 fasl −20ms 量级。
- .zo 体积:per-image 头/表/对齐 + 组内 symbol/rtd vspace 去重 → 31MB 应降(数值未知,待测)。2.2× 膨胀**不是**压缩损失:`compress-code?`/`compress-data?` 默认均关(linklet.sls:176-196)。

### 0.3 同闭包三根对照(2026-10-07 实测,交替 N=15 墙钟;PLT_LINKLET_TIMES 取 5 次 total 最小;ms)

| 节点 | fasl 根(15.8MB) | per-linklet vfasl 根(37.6MB) | bundle 合并(推断) |
|---|---|---|---|
| 墙钟 min / median | 180.7 / 182.9 | 173.4 / 174.5 | ~158-163 |
| process-ms / gc-ms | 169 / 51 | 161 / 49 | — / ↓ |
| boot | 25 | 23 | 不动 |
| read | 38 [+7 GC] | 35 [+39 GC] | ~17-20 |
| — read-bundle ×337 | 4 [+2] | 8 [+16] | ~5(镜像字节↓) |
| — faslin-literals ×1679 | 7 | 5 | ×337 → ~3 |
| — faslin-code ×1679 | 27 [+5],9MB | 22 [+23],26MB | ×337 → ~7.5 |
| instantiate ×1947 | 14 | 14 | 不动 |

GC 列:总 gc-ms 相等(51/49),vfasl 根的 read 期 [+39] 是**归属迁移**(26MB 镜像填满 gen0,回收提前到 read 期),不是新增成本——已验证。

## 1b. 开销标注的模块树(读侧,per-linklet vfasl 根;◆ = 本规格改动点,— = 不动)

```
racket -e '(void)'                                   墙钟 173 | process 161 | gc 49
├─ boot(3 个静态 vfasl 镜像)                           23          —
├─ read  .zo 装载                                     35 [+39]
│  ├─ expander read-linklet.rkt → cs/linklet/read.ss
│  │   read-linklet-bundle-hash ×337                   8 [+16]     ◆3.2.2 共享 literals 读时解码;镜像字节↓→拷贝↓
│  │     fasl-read(bundle 列表,含 26MB 镜像字节拷贝)
│  │     adjust-…-laziness-and-literals → vector->linklet / decode-linklet-literals
│  ├─ eval-linklet / instantiate-linklet(linklet.sls:851/865)      —(经 eval-from-bytevector)
│  │   └─ eval-from-bytevector ×1679                               ◆3.2.1 共享引用分派 → ×337
│  │       ├─ faslin-literals  extract-literals → force-unfasl-literals   5   ◆ 组 literals 一次 → ×337
│  │       └─ faslin-code                                        22 (26MB)
│  │           ├─ [S_vfasl 外,每镜像固定 ≈17.5 = 10.4µs×1679]      ← 合并主收益 ×337 ≈ 3.5
│  │           │    open-bytevector-input-port + fasl-read 头/entry 框架(7.ss:go1/go2,无拷贝)
│  │           │    $bv-fasl-read 外调(取 tc-mutex)→ bv_fasl_entry(fasl.c:546)
│  │           │    pthread_jit_write_protect_np ×2(version.h:352)
│  │           │    S_record_code_mod + S_flush_instruction_cache → sys_icache_invalidate ×1(vfasl.c:928,clearcache.c:46)
│  │           │    S_vfasl 头解析 + 10 vspace find_room 起手;thunk 调用;region 记账
│  │           └─ [S_vfasl 内阶段,PLT_VFASL_TIMES 扣 boot ≈ 4.5]   ← 按字节为主,合并后 ≈4
│  │                room+copy 0.8(find_room 0.2 / memcpy 0.5)
│  │                ptr-sweep 0.6
│  │                intern-syms 2.1          ← 同 bundle 5 成员重复 intern 同名符号;合并后组内去重
│  │                relink-code 0.4 · singletons 0.35 · symrefs 0.2 · rtds/closures 0.04
│  └─ (数据形状)每 bundle class-A 成员 = decl+data+0(358 个)或 +stx+stx-data(265 个);
│       1-4KB:327 · 4-16KB:182 · 16-64KB:91 · 64-256KB:22 · >256KB:1
├─ instantiate ×1947                                   14          —
└─ GC(全程)                                            49          推断:镜像字节↓ → gen0 压力↓
```

"S_vfasl 外"≈17.5ms 的构成是**推断**(按代码路径列举,未逐项计时);总量 = faslin-code 22 − 内阶段 4.5,已验证。
G1 直接用"1679 镜像 vs 337 镜像"的进程内 A/B 验证这块是否按镜像数线性下降。

### 写侧模块树(编译/序列化;◆ = 改动点)

```
compile-linklet(linklet.sls:650)
└─ compile-to-bytevector → compile*-to-bytevector(:408)
    ├─ compile-to-port*(:323) 单 form → 单 entry fasl 流;pred 收集 literals(call-getting-literals :340)
    └─ maybe-vfasl-code(:401)                        ◆3.2.1 模式 'linklet 才逐 linklet 转换;'bundle 保持纯 fasl
expander prop:custom-write → write-linklet-bundle(write-linklet.rkt)
└─ cs/linklet/write.ss write-linklet-bundle-hash(:9)
    └─ encode-linklet-literals(:24)                  ◆3.2.3 合并点:class-A 成员 → 一个 box
        ├─ strip.ss $vfasl-merge-bytevectors         ◆3.1.2 新原语
        │    ├─ read-and-strip-from-port ×N(:922)   ◆3.1.1 external-index-base 偏移(:329)
        │    ├─ $fasl-can-combine?(vfasl.ss:232)     —
        │    ├─ fasl-vector 根(同 boot write-out-accum,strip.ss:1089) —
        │    ├─ $fasl-to-vfasl(got? #f)              —(vfasl.ss 零改动)
        │    └─ $write-fasl-bytevectors(kind vfasl)  —
        ├─ fasl-literals(拼接后一次,schemify/fasl-literal.rkt:37)  —
        ├─ set-linklet-code / set-linklet-literals('#())            —
        └─ to-portable → linklet->vector;fasl-write* 整表(图共享保留 box) —
primdata.ss                                          ◆3.1.3 登记原语
C 层(vfasl.c / fasl.c)                               —(零改动)
```

## 1. 现状链路(改动落点标注 ◆)

```
compile-linklet (linklet.sls:650-)                      写侧
  └ compile-to-bytevector → compile*-to-bytevector (:408)
        compile-to-port*(一个 form,pred 收集 literals) → 单 entry fasl 流 bv
        ◆ maybe-vfasl-code(:401)  per-linklet:$vfasl-convert-bytevector
  └ make-linklet code=bv literals=vector preparation='faslable
write (expander prop:custom-write) → write-linklet-bundle-hash (write.ss:9)
  └ encode-linklet-literals (write.ss:24)  ◆ 合并点
        每 linklet:literals → fasl-literals;linklet->vector(to-portable)
        fasl-write* 整个 (key vec key vec ...) 列表 → 一个 bytevector(图共享保留)

read-linklet-bundle-hash (read.ss:2)                     读侧
  └ fasl-read 列表 → adjust-linklet-bundle-laziness-and-literals (read.ss:24)
        vector->linklet;decode-linklet-literals (◆ 共享 literals 需在此解码);
        preparation: 'faslable(read-on-demand-source) / 'faslable-strict / 'faslable-unsafe
eval-linklet (:851) 'faslable→'lazy;'faslable-strict→立即 eval-from-bytevector
instantiate-linklet (:865) 'lazy→eval-from-bytevector(双检锁)
  └ eval-from-bytevector (:428) ◆ 共享引用分派
        code-from-bytevector → load-compiled-from-port ip literals
        (7.ss:282-305:vector 根会 run-vector 全跑 → 共享形式必须改用 fasl-read 取向量)
```

Chez 层已具备的能力(勿重做):
- vfasl 根对象为"闭包向量"= boot 文件常态(strip.ss:1085-1091 `write-out-accum` 用 `fasl-vector` 合并多个 entry)。
- externalref:strip 读端把外部槽读成 `(fasl-indirect g (-1-j))`(strip.ss:311-331),vfasl.ss 编为 marker,vfasl.c `vfasl_external_ref` 仅做越界检查(vfasl.c:233)。
- 图头声明的外部个数 n = `table-external-count` = literals 向量长度(fasl.ss:840-842)。
- strip 读端拒绝非 `fasl-type-fasl` 的 entry kind(strip.ss:122)→ 已 per-linklet vfasl 化的流不可再合并 → 天然回退信号。

## 2. 设计

### 2.1 线格式(bundle fasl 内)

成员 linklet 的 `code` 槽:`#(|#%shared-code| <box> <idx>)`;`literals` 槽:`'#()`。
`<box>` 同组成员 eq? 共享(同一次 fasl-write 内图共享保留),内容:
```
#( <image-bv>        ; 一个 vfasl entry 的 fasl 流(kind=vfasl,situation=visit-revisit)
   <group-literals>  ; 写时:(fasl-literals (concat lits_0..lits_{N-1}) uninterned-symbol?) 的结果
                     ; 读时:被 unfasl-literals/lazy 替换(见 3.2.2)
   <loaded> )        ; 写出恒为 #f;加载后 = 向量 thunks(长度 N),见 3.2.1
```
成员顺序固定为 `(decl data stx stx-data 0)` 中实际存在者(确定性输出)。成员 i 的 literal j 在合并向量中的下标 = base_i + j,base_i = Σ_{k<i} |lits_k|。

### 2.2 镜像内容

根对象 = `(fasl-vector fasl-type-vector #(x_0 ... x_{N-1}))`,x_i = 成员 i 单 entry fasl 流的顶层对象(compile-to-port 产出的 thunk 闭包)。加载得向量 `thunks`;成员 i 的 linklet 过程 = `((vector-ref thunks i))`,与现 `load-compiled-from-port` 的 `run-outer` 对 procedure 的处理相同(7.ss:294)。

### 2.3 模式开关

`PLT_LINKLET_VFASL` = `1`/`linklet`:现有 per-linklet;`bundle`:本文;未设:fasl。读侧无开关(按 code 槽形状自动分派)。

## 3. 逐模块改动

### 3.1 Chez strip 层(无 C 改动,无 vfasl.ss 改动)

**3.1.1 strip.ss:外部下标偏移**
- 新 fluid 变量 `external-index-base`(默认 0),与 `external-base` 同处(:52)。
- :329-331 改为 `(fasl-indirect g (fx- -1 (fx+ external-index-base (fx- n external-base))))`。
- 正确性:默认 0 时与现行为逐位相同(boot 转换、per-linklet 转换、$describe 全不受影响)。

**3.1.2 strip.ss:新原语 `($vfasl-merge-bytevectors bv* count*)`**(紧邻 `$vfasl-convert-bytevector`,:1017)
- 入参:成员 fasl 流列表、各成员 literals 个数列表(调用方由 `(vector-length literals_i)` 给出)。
- 对第 i 个流:`(fluid-let ([external-index-base base_i]) (read-and-strip-from-port (open-bytevector-input-port bv_i) #f '#()))`;要求恰好一个非 header entry 且 `($fasl-can-combine? x_i)`,否则 `$oops`(调用方回退)。
- 读图头时记录声明的外部个数 n_i(:311 处的 `n`,经新 fluid `external-count-seen` 带出),断言 `n_i = count_i`;不等则 `$oops`(保证下标切片与 literals 拼接一致)。
- 组装 `(fasl-vector (constant fasl-type-vector) (list->vector x*))` → `($fasl-to-vfasl v)`(got? 缺省 #f,gen0 语义,同 per-linklet)→ `$write-fasl-bytevectors` 为单 entry(visit-revisit, kind vfasl)→ 返回 bytevector。
- 正确性:(a) 各流 AST 节点身份互不相交,合并不引入伪共享;(b) 组内 symbol/rtd 在 vfasl 写端按名/uid 去重,属 vfasl 既有语义;(c) 与 boot 的 `write-out-accum` 同构。
- 回退信号:成员流 kind≠fasl(已是 vfasl)、多 entry、不可合并、n 不符 → 异常。

**3.1.3 primdata.ss**:登记 `($vfasl-merge-bytevectors [sig [(list list) -> (bytevector)]] [flags])`。

**3.1.4 构建影响**:改 s/*.ss → 必须删三处 boot 文件后 `make base`(见 memory `racket-chez-boot-rebuild-gate`);无 vfasl.ss/C 改动,PIC battery 不需重跑,self-host fixpoint 需过。

### 3.2 linklet 层

**3.2.1 linklet.sls**
- `vfasl-code-mode`(:401 一带):解析 env 为 `#f | 'linklet | 'bundle`。`maybe-vfasl-code` 仅在 `'linklet` 时转换;`'bundle` 时保持纯 fasl bv(合并延后到 bundle 写出)。嵌套 `wrapped-code`(jitify/'interpret 格式,闭包中 7 个)不参与,行为同今。
- `eval-from-bytevector`(:428)开头加分派:`(if (shared-code-ref? bv) (shared-code-load bv) ...)`。
- 新函数:
  ```scheme
  (define (shared-code-ref? v) (and (#%vector? v) (fx= 3 (#%vector-length v)) (eq? '|#%shared-code| (#%vector-ref v 0))))
  (define (shared-code-load ref)
    (let* ([bx (#%vector-ref ref 1)] [idx (#%vector-ref ref 2)] [data (#%unbox bx)]
           [thunks (or (#%vector-ref data 2)
                       (let ([v (performance-region 'faslin-code
                                  (fasl-read (open-bytevector-input-port (#%vector-ref data 0)) 'load
                                             (extract-literals (#%vector-ref data 1))))])
                         (with-interrupts-disabled
                           (or (#%vector-ref data 2) (begin (#%vector-set! data 2 v) v)))))])
      ((#%vector-ref thunks idx))))
  ```
  - 并发:与 instantiate 现有 'lazy 路径同一模型(双检 + 幂等:重复加载得到等价 thunks 向量,后写者胜,成员过程由 linklet-code-set! 各自记忆)。
  - `fasl-read` 三参形式即 'interpret 路径现用形式(:432)。不用 `load-compiled-from-port`(vector 根会被 run-vector 全部执行)。
  - `add-performance-memory! 'faslin-code` 对共享引用改为按 image 首次加载计一次(字节 = image 长度)。
- `linklet-fasled-code+arguments`(:955):共享形式返回 `(values 'shared-vfasl ref '#())`(树内无调用者,保持可调用)。
- `eval-linklet`/`instantiate-linklet`:不改(都经 eval-from-bytevector)。

**3.2.2 linklet/read.ss**
- `adjust-linklet-bundle-laziness-and-literals`(:24):对 code 为共享引用的 linklet,取 box 数据向量,若槽 1 尚未解码(bytevector 或 `(bstr . exposed)` 对)则 `(vector-set! data 1 (unfasl-literals/lazy raw))`;已是 `'#()`/box 则跳过(同一 box 在同一 bundle 内被多个成员命中,幂等)。
- 必须在**读时**做而非加载时:`unfasl-literals/lazy` 捕获 `current-load-relative-directory`(schemify/fasl-literal.rkt:56-62),路径类 literal 的相对基准来自 .zo 所在目录;延后到 eval 会取错目录。
- `decode-linklet-literals` 对成员(literals='#())走 `(vector? literals)` 分支,不改。
- `adjust-linklet-laziness`:不改(preparation 语义与成员形式无关)。

**3.2.3 linklet/write.ss `encode-linklet-literals`**(:24)
- 入口先扫描 hash,收集合并候选:key ∈ `(decl data stx stx-data 0)` 且 `(linklet? v)` 且 format='compile 且 code 为 bytevector 且 preparation ∉ {callable, lazy} 且非 cross-machine。候选数 ≥ 2 才合并(单成员无收益)。
- 合并:按固定顺序取成员,`lits_i = (extract-literals (linklet-literals l_i))`,`count_i = (vector-length lits_i)`;`(guard (c [#t #f]) ($vfasl-merge-bytevectors code* count*))`;失败 → 整组回退为现行逐 linklet 写法(写出的 bv 保持纯 fasl;若需 per-linklet vfasl 可在此对每个成员再调 `$vfasl-convert-bytevector`)。
- 成功:构造 `data = (vector image-bv (fasl-literals (vector-concat lits*) uninterned-symbol?) #f)`,`bx = (box data)`;成员 i 替换为 `(set-linklet-literals (set-linklet-code l_i (vector '|#%shared-code| bx i) prep_i) '#())`,再走原 `linklet-pack-exports-info!`/`to-portable`。
- **重写路径**(读入的 .zo 再写出:`compiled-expression-recompile`、demod、`write` 已读 bundle):成员 code 已是共享引用 → 不重新合并;以每次写出一张 eq-hashtable 映射旧 box→新 box(保持组内共享、`loaded` 槽置 #f、槽 1 若已被解码为 lazy box 则 `(fasl-literals (extract-literals …))` 重新序列化,与现 per-linklet 重写路径同式)。
- `check-fasl-preparation`、`adjust-cross-preparation`:不改。
- 确定性:成员顺序固定、`$fasl-to-vfasl` 对相同输入输出相同(per-linklet 模式已依赖此性质)。

**3.2.4 不改的模块(需逐条验证其假设仍成立)**
- expander `compile/linklet.rkt`、`read-linklet.rkt`:只经 `write-linklet-bundle-hash`/`read-linklet-bundle-hash`,bundle key 集不变(不新增 key,避开 `recompile.rkt`、`module.rkt:420` 对 key 的遍历假设)。
- `raco exe` 嵌入:复制 .zo 字节,不重序列化。
- cross-compile(`current-compile-target-machine` ≠ 本机):候选过滤排除;写出走 `cross-fasl-to-string` 原路径。
- `read-on-demand-source` = #f('faslable-strict,eval-linklet 立即 eval):首个成员触发镜像加载,其余成员命中 `loaded`。
- 非 root code inspector('faslable-unsafe → eval 抛错):不变。

## 4. 不变量与边界用例清单(G2 必测)

1. 成员 literal 下标切片:`merged[base_i + j] ≡ lits_i[j]`(由 3.1.2 的 n_i=count_i 断言 + 固定顺序保证)。
2. 同 bundle 不同成员的同名 literal 为不同对象(与现状一致;不做跨成员去重)。
3. 路径 literal 的 load-relative 基准 = 读 .zo 时的目录(3.2.2)。
4. 含 uninterned symbol 的 literals(`fasl-literals` 返回 `(bstr . exposed)` 对)经 box 槽 1 走同一 lazy 解码。
5. 一个 bundle 只有 decl+data+0 三成员 / 有 stx+stx-data 五成员 / 含 'interpret 格式成员(排除后 <2 成员则不合并)。
6. 已 per-linklet vfasl 化的 .zo 再以 bundle 模式重写:原语抛错 → 回退,不得静默损坏。
7. 读入 bundle 模式 .zo → `compiled-expression-recompile` → 写出 → 再读 → instantiate 正常(重写路径 box 映射)。
8. 两个 place 同时首次 instantiate 同组成员:幂等,无崩溃(用 `place` 并发 dynamic-require 同一模块的两个子模块验证)。
9. 旧二进制读新 .zo:会在 eval 处报错(code 槽非 bytevector)。接受(实验门控),记录在文档。

## 5. 门禁与测量

- **G1(先于 3.2 全部工作)**:只做 3.1,重建 boot;scratchpad 脚本用 `vm-eval` 对闭包每个 bundle 的 class-A 代码流做进程内 A/B:A=逐成员 `$vfasl-convert-bytevector` 后逐个 `fasl-read 'load`;B=`$vfasl-merge-bytevectors` 后一次 `fasl-read 'load`;C=纯 fasl 逐成员。externals 用定长 #f 向量(越界检查以外无语义)。各 5 轮取 min,轮间 `(collect)`。
  通过线:B 相对 A ≥ −6ms(预测 −12ms 的一半);不达则停,回到固定成本分解(W^X 切换、`S_thread_start_code_write`、symbol 重 intern 各占多少)。
- **G2 正确性**:bundle 模式编译闭包到独立根(`PLTCOMPILEDROOTS="$R/:"`,`racket -l- compiler/commands/make`,`raco make` 在本树不可用);`PLT_LINKLET_TIMES` 显示 faslin-code 次数 ≈ 337;basic.rktl + 之前跑过的核心段;§4 用例 5-8 各写最小脚本。
- **G3 性能**:安静机器、交替 A/B/C(fasl 根 / per-linklet 根 / bundle 根)各 ≥ 15 次,报 min/median;.zo 总字节三列。
- **G4 构建**:`make base` rc=0 + self-host fixpoint;无 C/vfasl.ss 改动故不重跑 PIC battery。

## 6. 顺序与工期(单人,含构建等待)

1. 3.1.1-3.1.3 + 删 boot 重建 ≈ 45 min 编码 + 15 min 构建。
2. G1 脚本与测量 ≈ 45 min → 决策点。
3. 3.2.1-3.2.3 ≈ 2 h 编码 + 15 min 构建。
4. G2 ≈ 1.5 h;G3 ≈ 45 min;文档/memory ≈ 20 min。
合计约 1 个工作日。

## 7. 未知与风险

- 固定成本的构成未分解(W^X 切换、符号重 intern、per-image find_room、GC 元数据)——G1 直接测总量,不依赖分解。
- 合并后单次加载的 gen0 大块分配对后续 minor GC 的影响未知(per-linklet 实验里 GC 反而变少,推断合并同向)。
- class-B(phase≥1,252 linklet 2.57MB)不在 v1;影响"第一条输入的展开延迟"而非 time-to-prompt。
- 体积:合并消去 per-image 头/表与组内 symbol 重复,数值待 G3。

## 8. G1 结论(2026-10-08,已验证)— 门禁未过,合并线关闭

实现了 §3.1(strip 原语,boot 重建 rc=0),进程内 A/B(`g1-bench.rkt`,闭包 623 bundle / 2395 class-A 成员 / 6.68MB 代码流,5 轮取 min,三次独立运行一致):

| 变体 | 镜像数 | ms |
|---|---|---|
| A 逐成员 vfasl(+249 个无法转换的纯 fasl) | 2146 + 249 | 12.2 / 13.4 / 15.2 |
| B 每 bundle 合并(+249 纯 fasl) | 623 + 249 | 11.8 / 13.7 / 15.0 |
| C 纯 fasl | — | 19.1 / 21.0 / 23.3 |

- **B − A = −0.4 / +0.3 / −0.2 ms;每镜像固定成本 ≈ 0.2µs**,不是 §0.2 推断的 9.5µs。§1b 中"S_vfasl 外 ≈17.5ms = 每镜像固定"的推断**错误**:那部分不随镜像数缩放(候选:冷缓存/交错执行/镜像字节量经 read-bundle 拷贝与 GC,未分解)。
- 合并的字节收益仅 6%(23.4MB → 22.0MB)。
- **裁决:bundle 级合并不做**;strip.ss/primdata.ss 改动已回退(当前二进制仍含该原语,下次 boot 重建消失)。

### 8.1 同一实验暴露的真实杠杆(已验证)

1. **覆盖缺口**:249/2395 成员转换失败,全部为 `vfasl: unsupported #<rtd-ref>`(compile-to-port 用 `'omit-rtds`,已注册记录类型的 rtd 字面量只写 uid;vfasl.ss 无此节点)。这 249 个成员占 **54% 代码字节(3.63MB / 6.68MB)**,是大 linklet(定义 struct 的模块体)。per-linklet vfasl 根实际只转换了 46% 的代码字节。
2. **已转换集合上 vfasl = 2.8×**:2146 成员 vfasl 3.8ms vs 纯 fasl 10.5ms;残留 249 成员纯 fasl 8.7ms。
   → 支持 rtd-ref 后(推断,按 2.8×):8.7 → ~3.1ms,A 12.2 → ~6.6ms;实机 faslin-code 22 → ~12ms 量级。
3. **镜像膨胀是内容级不是头部级**:启动期 1230 个 .zo 镜像 16.5MB(对应 ~1.7MB fasl 流),按 vspace:impure 7.2MB(44%)、data 4.6MB(28%)、symbol 2.3MB(14%)、code 2.1MB(13%)、reloc 0.3MB。per-image 头/表可忽略,所以合并无字节收益。impure/data 的构成未分解(推断:code-info 名字/srcloc、字面量数据被按内存布局原样物化)。它决定 read-bundle 多出的 4ms 与 GC 体积。

### 8.2 改向建议

- **下一步 = vfasl 支持 rtd-ref**(覆盖 46% → ~100%)。线格式:数据位用 symref 低位标志(槽内存 uid 符号索引,C 侧 symrefs 循环中按 uid 的 plist `rtd_key` 查已注册 rtd,缺失即报错,与 fasl.c:964 的 "unregistered record type" 同语义);code reloc 用剩余的 1 个 3-bit tag(`vfasl-reloc-rtd-uid-tag`,relink_code 同查法)。改动面:cmacros 1 常量、vfasl.ss `rtd-ref` 节点两处 fasl-case*(数据/reloc)、vfasl.c symrefs 循环 + relink_code 各 ~10 行。boot 不产生 rtd-ref,风险局限于 .zo 路径;门禁 = boot 重建 fixpoint + per-linklet 根重编后 `faslin-code` 字节覆盖 100% + 核心测试。
- 其后再分解 impure/data 的对象构成(vfasl 写端加按类型字节直方图),决定是否值得压缩镜像内容。

### 8.3 转换失败的精确原因(2026-10-08,已验证)

在 120 个最小的失败流上逐文件 describe(`rtd-file.ss`,单进程一文件,0 崩溃):114 个引用 `code-info` + `source-2d` + `source-file-descriptor`(Chez 为 code 对象挂的源信息记录;Racket CS 以 `generate-procedure-source-information #t` 编译,每个 code 对象带 code-info→source-2d→sfd),少数引用 rumble 的非生成式记录类型(impersonator 11、eq-mutable-hash 5、udp/tcp-listener/struct-type-prop/logger/inspector 各 1)。对最小失败流做 `strip-fasl-file`(去 inspector-source + source-annotations)后 rtd 引用 = 0,即可转换——证实失败全部源于"按 uid 引用的已注册记录类型"。

链路:linklet.sls:336 `compile-to-port … 'omit-rtds` → fasl.ss:585 对非 ftd 的 rtd 只写 `fasl-type-rtd` + uid + size 0("must be registered already at load time")→ 纯 fasl 读端 fasl.c:936-966 按 uid 在符号 plist 的 `rtd_key` 查已注册 rtd(缺失报 "unregistered record type")→ vfasl 路径 strip.ss:238 把 size-0 读成 `(fasl-rtd-ref uid)` 节点 → vfasl.ss 的 `copy` 无此节点分支 → :1087 `unsupported` → linklet.sls `maybe-vfasl-code` 的 guard 静默回退纯 fasl。

### 8.4 修法改为"转换端物化 rtd"(替代 8.2 的 C 侧新 tag 方案)

转换发生在编译进程,被引用的 rtd 在该进程**已注册**(code-info 等是 boot 系统类型,rumble 类型随运行时加载)。在 strip.ss 读端加 fluid `materialize-omitted-rtds?`(仅 `$vfasl-convert-bytevector` 置 #t):size-0 时用 `(gensym pretty unique)` 取回 uid 符号 → `($sgetprop uid '*rtd* #f)`(record.ss:618 同一注册表)→ 命中则把活 rtd 以**不带 omit-rtds** 的 `fasl-write` 写入临时 bytevector,再 `read-fasl` 读回成完整 `record` 节点替换 rtd-ref(按 uid 记忆化,保持镜像内共享);未命中则 `$oops`(维持回退)。加载端零改动:完整 rtd 走 rtd vspace 的既有 `S_fasl_intern_rtd` 按 uid 查找/替换(boot 镜像常态,vfasl.c:815-882)。改动面 ≈ 40 行 strip.ss;不动 vfasl.ss / C / cmacros;boot 不产生 rtd-ref 不受影响。门禁:boot 重建 fixpoint + 重编 per-linklet 根后 `g1-bench.rkt` 覆盖 2395/2395 + `faslin-code` 实机复测 + 核心测试(backtrace 的 srcloc 必须仍在:code-info 保留)。
