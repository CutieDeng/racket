# vfasl externalref 扩展 — 实现规格（可执行蓝图）

2026-09-17 · 目标=让 vfasl 支持外部 literals（externalref），使 racket/init+xrepl 的 .zo 编译码可 vfasl 化（faslin-code 5.4×、体积 0.38×、crash-free）。可行性/影响面/自举兼容性全在 [[racket-repl-startup-project]] + `repl-startup-forward-design.md` §7；本文是**实现蓝图**。

## 0. 已验证的底座（勿重走）

- vfasl 经 `.zo` 装载原语 `load-compiled-from-port` 装载 = **5.4× 快 / 0.38× 体积 / 正确运行**（§7.4c）。
- 干净配方：`compile-to-port`(debug 关) → vfasl-convert-file(deps petite+scheme+racket) → load-compiled-from-port。**无需 strip**（debug 关则无 code-info）。
- 障碍：外部 literals（strings/bytes/keywords/regexps/hashes/gensyms/paths/…，由 schemify `register-literal-serialization` 判定，**常态**）→ `vfasl-convert-file` 报 "incompatible external vector"（strip.ss:287）→ 回退 fasl 覆盖率低 → **externalref 扩展是必要前置**（§7.4f/g）。
- 影响面/自举：只碰 vfasl 不碰 fasl；bump scheme-version 防护；自举流程/pb 最小运行时/configure 全照旧（§7.4h）。

## 1. fasl 外部引用的现有表示（关键：AST 节点已存在）

- fasl 流中 code 引用外部 literal[i] = `fasl-type-graph-ref` + uptr `n`（strip.ss:301-304）。
- 读时：`(or (vector-ref g n) (fasl-indirect g n))`——**g 无该项时产 `fasl-indirect` 节点**（AST 节点 `indirect (g i)`，strip.ss:30）。
- `fasl-type-graph`（strip.ss:284-294）声明"需 n 个外部"；standalone（g=#f、n>0）→ **`bogus "incompatible external vector"`（第 287 行）= 现障碍点**。

→ 扩展 = 把已存在的 `fasl-indirect` 节点**穿过 vfasl 路径**（strip 放行 → vfasl.ss 编码 → vfasl.c 解析），而非发明新表示。

## 2. 线格式变更

- **cmacros.ss ~2326**：`vfasl-reloc` 枚举加 `vfasl-reloc-external-tag`（现 6 个，3-bit=8，余 2）。
- **cmacros.ss ~2293 `vfasl-header`**：末尾加 `[uptr externalref-count]`（在 singletonref-count 后）。→ header 布局变=所有 vfasl 镜像重生成（§7.4h 已评估）。
- **cmacros.ss:360 `scheme-version`**：bump `#x0a050001`→`#x0a050002`（防旧 vfasl boot 静默错读）。

## 3. 逐文件改动（精确插入点）

### 3.1 strip.ss（fasl 解析：放行外部引用）
- **第 287 行**：`fasl-type-graph` 处，`(zero? n) ∨ (and g (>= (vlen g) n))` 不满足时不再 `bogus`，改为**建 size≥n 的占位 g**（缺项留 #f）→ 使 graph-ref 产 `fasl-indirect`。
  - 注意 delta 拷贝逻辑（288-293）保留；占位 g 只需容纳 n 项。
- 校验：read-and-strip 后，带外部 literals 的 code AST 含 `fasl-indirect (g i)` 节点、不报错。

### 3.2 vfasl.ss（编码器：fasl-indirect → externalref 表项）
- `fasl-case*`（~207/~528 build/sweep 两处）加 `indirect` 分支：
  - build 阶段：为 indirect 分配一个"externalref 占位槽"（类似 singletonref，记录 (offset . index)）。
  - sweep/relink：把该槽登记进 externalrefs 表（新增，仿 `singletonrefs`）。
- vfasl-info（~20-47）加字段：`externalref-count`、`externalrefs`（offset 数组），仿 singletonref 三处（count/refs/offset）。
- header 写出（~101/~123）加 externalref-count（仿 singletonref-count 的 set-uptr!）。
- 表布局（~144）在 singletonrefs 后追加 externalrefs 块。
- **约束**：`installs-library-entry?`（vfasl 组合性）不受影响；externalref 是纯"装载时按索引查 externals"。

### 3.3 vfasl.c（装载器：解析 externalref + 穿 externals）
- **S_vfasl 签名**（externs.h:142 + vfasl.c:202）：加 `ptr externals` 参数。
- **fasl.c**：`bv_fasl_entry`（~526）与 boot 路径（~504）调 S_vfasl 时把已有的 `externals` 传入（fasl 路径已在用 externals，vfasl 路径现丢弃）。
- **vfasl.c header 读**（~318-321）：在 singletonrefs 后读 externalrefs 表（VFASLHEADER_EXTERNALREF_COUNT）。
- **vfasl.c 解析循环**（仿 singletons ~418-421）：新增 phase `vfasl_phase_externalrefs`；
  ```c
  for each externalrefs[i]:
    r_off = externalrefs[i]; ref = <slot at r_off>;
    *ref = Svector_ref(externals, UNFIX(*ref));   // 照抄 lookup_singleton 模式，源换 externals
  ```
  - `externals` = #f（boot/无外部时）→ externalref-count 必为 0，循环不跑（boot 无外部引用，天然兼容）。
- vfasl_phases 枚举（~106）加 externalrefs 项 + 计时名（~111）。

### 3.4 externs.h + fasl.c 签名穿透
- S_vfasl 所有调用点（vfasl.c:642 `S_vfasl_to`、fasl.c:504/527）传 externals（boot 路径传 Sfalse/Snil）。

## 4. 验证（每步，重建后）

1. **Chez 层直测（已设计，scratchpad/extlit3.ss 变体）**：`compile-to-port`(带 external?-pred 捕获 literals) → strip 不需要（debug 关）→ **新 vfasl-convert-file（externalref 版）** → `load-compiled-from-port bv literals`；断言 `(pf 99)=(pv 99)`（外部 literal 装载时正确 patch）。
2. **回归**：既有 vfasl 无外部引用者（boot/§7.4c 的 6000 过程）仍 5.4×、正确——externalref-count=0 路径不变。
3. **boot 自举**：`make re.boot`（或 make base）全绿；`scheme -q` 起、`racket -e '(void)'` 起（新格式 boot 装载）。
4. **端到端**：linklet.sls 写侧出 externalref-vfasl，重编一 collection .zo，`PLT_LINKLET_TIMES` 量 faslin-code 降幅（预期 33ms→~6ms）。

## 5. 重建 + 回滚

- **重建**：改 cmacros→全 Chez 重建。C-Scheme 同步改→`make re.boot`（BUILDING:189 明示此场景）。native 本机 `make base`（tmux seg4）。
- **回滚**：逐文件 `git checkout HEAD -- <file>`（cmacros.ss/strip.ss/vfasl.ss/vfasl.c/externs.h/fasl.c）；git-restore-discipline 精确到文件。
- **顺序**：先 3.1+3.2（编码，Chez 层可单测 vfasl-convert-file 不崩）→ 3.3+3.4（装载，需重建）→ bump 版本 → re.boot → 验证。

## 6. 覆盖与护栏

- externalref 覆盖**全部**外部 literal（paths 保持外置=可移植）。边缘不支持类型（若有）→ linklet.sls 写侧回退 fasl（`literals` 判定）。
- 护栏：externalref-count=0 时全路径=旧行为（boot/无外部码零影响）。

## 7. 风险登记

- vfasl.ss 编码器/vfasl.c 装载器是 Chez 内核精密代码，错误→运行时损坏；**每步 Chez 层单测 + 回归 + boot 自举三关**。
- cross 编译需 host+target 同改（native 本机无）。
- 预置 racket.boot（BOOTFILE/发行）随版本重生成。

## 8. 端到端实测（2026-09-17，build11 tarm64osx，本机 M 系）

**结论先行**：externalref 扩展**编码/装载正确性已全验证**；但把 linklet code 走**运行时 faslin-code 路径**（`load-compiled-from-port`，`S_vfasl_boot_mode=0`）vfasl 化**不加速启动，反而更慢**——推翻 §0/§4 的 "5.4×/33ms→6ms" 预期（那是 boot 直入 static 路径的数，运行时路径不适用）。

### 8.1 已验证（实测数据）

- **正确性**：code-reloc 外部（`(list x "a" "b")`）与 data-position 外部（`'#("a" "b" "c")` 内嵌）均 `vfasl-convert-file` 通过且 load+run 与 fasl bit 一致（`match=#t`）。规模测 7200/28800/57600 外部 string 全过。里程碑（不再报 "incompatible external vector"）达成。
- **构建**：build11 EXIT:0。pb 自举内核用 upstream v9.3 头，`#ifdef vfasl_reloc_external_tag` 守卫使其跳过该 tag 编译通过；native 用 `#define VFASL_EXTERNAL_BASE 0x40000000`（不依赖 equates.h，pb 安全）编入 data-external。
- **真实 linklet（huge.rkt，4500 函数，big.rkt 同形放大 15×）**：
  - .zo 体积：fasl 503KB → vfasl 1.38MB = **2.74× 更大**（非 0.38×；真 linklet 外部/引用密度高，vfasl 引用表+重定位位图撑大）。
  - **懒装载被打破**：`(require huge)` 只调 f0 时 faslin-code：fasl≈**0ms**（fasl 按过程懒装，未调用者不装），vfasl≈**7ms**（vfasl 整镜像 eager）。启动最需要的懒装载 fasl 已有，vfasl 打掉它。
  - **eager-vs-eager**（强制调用全部 4500 函数，同一 harness 只换 .zo，15 次取分布）：fasl faslin-code 中位 **8ms**（7 7 7 7 7 7 8 8 8 9 9 9 10 10 12），vfasl 中位 **12ms**（9 11 12 12 12 12 12 13 13 13 14 14 14 15 17）→ vfasl **~1.5× 慢**。
- **合成扫描佐证**（同一进程内 tight-loop 计 load 时；含每-code-object 开销放大，绝对值不代表真 linklet，但 fasl-vs-vfasl 方向一致）：外部密码轻码 vfasl 小尺寸 1.4-1.5× 快、310KB 趋平；码重（真 linklet 形）vfasl 1.2-2.6× 慢。

### 8.2 根因（代码已证 + 推断）

- **已证**：`to_static = (S_vfasl_boot_mode > 0)`（vfasl.c:262）。运行时 bytevector 装载 boot_mode=0 → to_static=0 → 镜像落 generation 0 做**逐对象全重定位**，非 boot 期直入 static 的批量路径（find_room 用 `static_generation` vs `0`，line 285）。
- **推断**：vfasl 的启动优势（引用的 ~5.4×）绑定在 **boot 期 direct-to-static** 路径；运行时 .zo faslin-code 路径从不走它，故不继承该优势，且更大镜像+引用表 walk 比 fasl 流式反序列化更慢。**缺口**：未直接实测 boot-segment 内的 externalref-vfasl 装载确认其在该路径更快——需把码接进真 boot 段。

### 8.3 对项目的意义（修正定位）

- externalref 扩展的价值 = **第四 boot 段设计（把语言层预实例化进 vfasl boot 段、走 direct-to-static）的必要使能件**——该段含带外部 literal 的 linklet code，扩展前无法在 vfasl 中表示（"incompatible external vector"）。
- 它**不是**运行时 per-.zo 码装载的直接加速；那条路上是 regression。`PLT_CS_VFASL_CODE`（linklet.sls 原型）应保持 gated 实验，**不默认开**。
- 下一步真正的加速验证 = 走 boot 段（direct-to-static），不是继续在 faslin-code 运行时路径上量。

## 9. to_static 假设被证伪 + "5.4×" 是基准假象（2026-09-17 决定性更正）

**两条早期结论被实测推翻**：

### 9.1 to_static 不是加速来源（证伪 §8.2 推断）

同一 6000-proc code 两路装载，PLT_VFASL_TIMES 相位计时：
- **boot 路径**（ts-vfasl.boot 经 `-b` 装载，`S_vfasl_boot_mode=1`→to_static）：相位合计 ~4.3ms（room+copy 2.12 其中 memcpy 2.09 / ptr-sweep 0.99 / intern 0.37 / closures 0.24 / relink 0.35…）。
- **runtime 路径**（同码 bare bv, load-compiled-from-port, `boot_mode=0`→gen0）：相位合计 ~3.4ms（room+copy 1.33 其中 memcpy 1.30 / ptr-sweep 0.93…）。
- **runtime 反而更快**（memcpy 1.30 vs 2.09——static-gen 页首触缺页比复用 nursery 热页更贵）。⇒ **to_static 不使 vfasl 装载更快**；装载相位工作与目标世代无关。§8.2 的 "vfasl 优势绑定 direct-to-static" 推断**错误**。
- 副产物（已证）：boot baseline（petite+scheme only）PLT_VFASL_TIMES **零输出** = petite/scheme boot 是 fasl 非 vfasl（与 memory 一致）。

### 9.2 "5.4×/6× 更快" 是"多顶层 form load+eval"的假象，不代表 linklet

同 build11 同码 wall-clock：
- **6000 顶层 `define`（compile-port，ts）**：fasl 54ms vs vfasl 9ms = **6× 快**（复现历史 5.4×）。但 `load-compiled-from-port` 对顶层 form 是 **load+eval**——跑 6000 个 define 装全局；vfasl 把 6000 form 塌成一镜像跳过逐 form eval 开销。vfasl 9ms 里真 S_vfasl 仅 3.4ms，余 5.6ms 是 bv_fasl_entry/端口/读盘。
- **huge.rkt linklet（4500 闭包，同 build11）**：fasl 8ms vs vfasl 12ms = **vfasl 1.5× 慢**。linklet = **一个顶层 form**，load-compiled-from-port 产 linklet 过程**不 eval**（实例化另算）。
- **单表达式合成（loadbench3，(lambda ... (list closures)))）**：亦 vfasl 慢。
- ⇒ 真 `.zo` = 每模块一个 linklet = 一个顶层 form（load 无 eval）= huge.rkt 情形 = **vfasl 慢**。历史"许多 code 对象→vfasl 赢"结论把 ts 的多顶层-form load+eval 误当 linklet code-load，**证伪**。

### 9.3 净结论（诚实收口）

- **vfasl 不加速真 Racket linklet code 装载**——任何路径（runtime **和** boot/to_static）皆然。历史 5.4× 系基准构造（多顶层 form load+eval）产物，非 code-load 速度。
- externalref 扩展**正确性完整**（code-reloc + data-external 全验证），但其原定收益前提（vfasl 使 linklet code 装载更快）**不成立**。`PLT_CS_VFASL_CODE` 不应默认开。
- **启动主成本是实例化（instantiate，跑 linklet body 建语言层活状态 ~70ms GC）非 code 装载**（faslin-code 全程仅 ~26ms）。vfasl 触不到 instantiate。真解仍在**预实例化**（消 instantiate 本身），即 memory 的 P0-P1 闭包序列化线；vfasl code 格式是死胡同。
- **唯一未证伪的 vfasl 可能收益**=把 startup 数百 linklet **合并成一镜像**消 per-load-call 固定开销（~5.6ms/call 级），但 racket/base faslin-code 仅 26ms、且被 instantiate 主导，上界小，未测。
