# REPL 启动：当前调用树、开销、设计与数据流（2026-10-19 收尾状态）

测量对象：分支 feat/repl-startup-analysis 六次提交后的 in-place 构建（G1 74f05f2e6c → C2 5900d85b70），安装已全量重编为压缩 .zo。机器 Apple M5 Max，测量期间负载 4–8（绝对值 ±5ms）。两种配置：`racket -q </dev/null`（语言层：racket/init，无交互模块）与默认 tty REPL（pty，加载 racket/interactive + xrepl，到 `> ` 出现）。数字来源：PLT_EXPANDER_TIMES / PLT_LINKLET_TIMES（CPU，区域互斥、自含）、PLT_LINKLET_TRACE_TIMES（实例化区间）、PLTSTDERR=debug@GC、alloctrace.rkt（分层分配）、tree-probe.py。标注：**已验证**（有实测）、**推断**（有间接证据）、**未知**。

## 1. 调用树与开销

```
exec racket/bin/racket (52KB launcher) → Racket.framework dylib                              ─┐
  Sbuild_heap: petite.boot 11.6MB + scheme.boot 7.0MB + racket.boot 35.2MB (vfasl, 静态代 55.9MB)  │ boot 25–29ms (linklet 'boot 25/26)
  racket_boot → main.sps                                                                      ─┘
  main.sps
  ├ 解析 flags；PLT_STARTUP_GC_MODE：文本 REPL 时 (set-startup-gc-mode! #t) → 窗口开（只收 gen 0，fasl 产物出生 gen 1）
  ├ expander 启动：#%kernel 等原语实例、模块注册表、标准 resolver/load handler 安装（boot/handler.rkt）
  ├ (namespace-require init-library) ─ init-library = racket/init（默认）                      ── 语言层 ≈ 95ms (-q ttp 120/124 − boot)
  │   每个 require/声明依赖 → module-path-index-resolve
  │   ├ resolver 区域（common/module-path.rkt:223 包住 (current-module-name-resolver)）
  │   │   -q: 25.2ms / 15.6MB / 2844 次；默认: 36.4ms / 21.9MB / 6662 次（自含，不含下面的 read/module/instantiate）  已验证
  │   │   = standard-module-name-resolver：`(lib ..)`/相对路径解析、path-cache(按注册表弱表)、find-col-file 探测
  │   │     (directory-exists?/file-exists? 过 collection links+paths)、default-load/use-compiled → choose-file-to-load
  │   │     (.zo/.rkt 日期比较：PLT_COMPILED_FILE_CHECK=exists 对比 modify-seconds 无差，日期 stat 不是成本 已验证)
  │   │     → default-load-handler：open-input-file(332 文件 4.8ms/1.8MB 已验证) → linklet-directory-start/search-directory(seek)
  │   ├ read 区域（read-syntax 读 `#~`）  -q: 10.9ms / 22.7MB / 398；默认: 14.4ms / 26.1MB / 524        已验证
  │   │   └ CS read-bundle  -q: 8ms/328；默认: 11ms/383（R1 后：read-bytes 结构段 + fasl-read 外层 + read-bytes code area + 单次 make-linklet）
  │   │       外层 fasl 主 bundle 合计 12.7MB：code 10.3MB、符号出现 60350、对 82135、其他 40339（6.0ms 独立实测）
  │   ├ module 区域（eval-module 声明）  -q: 16.0ms / 17.3MB / 328；默认: 20.1ms / 20.0MB / 383        已验证
  │   │   ├ decl linklet：faslin-code + 实例化（trace self 13.0ms/383）→ 反序列化 provides/requires（D2 批量建 HAMT）
  │   │   ├ data linklet：mpi 向量（trace 4.6ms/383）
  │   │   ├ stx-data：D1 代理，声明时不物化（默认 REPL 到提示符 100 次被宏触发物化，trace 6.0ms）
  │   │   └ module 结构 → 注册表（resolved-module-path → module）
  │   ├ requires 区域  -q: 4.2ms / 5.5MB / 2272；默认: 7.8ms / 10.3MB / 5355（require 列表的 mpi 解析/记账）  已验证
  │   └ instantiate 区域（namespace-require 触发 phase-0 实例化，链式）
  │       -q: 16.7ms / 33.3MB / 244 实例；默认: 57.0ms / 98.0MB / 734 实例（含 xrepl 触发的 phase-1 visit）   已验证
  │       每个模块实例：stx linklet（字面量向量）→ body linklet eval-from-bytevector
  │         faslin-code  -q: 19ms/1089 个 linklet 5MB；默认: 42ms/1716 个 9MB（LZ4 解压 21%、fasl 解码 45%、intern 13%、icache 3%）
  │         → 代码对象出生 gen 1（C2）→ instantiate-linklet：变量创建/导入提取 + 跑 body
  │         linklet 'instantiate  -q: 10ms/1089；默认: 39ms/2040（模块体真正执行 ≈ 6–7ms/7.8MB，晨间探针）
  ├ 默认 REPL 才有：
  │   ├ racket/interactive = collects/racket/interactive/tstring.rkt：trace self 82.8ms（含其触发的装载/visit：
  │   │   syntax-color/racket-lexer 5.0ms、parser-tools/lex 1.3ms、id-table 3.1ms、…；expeditor 初始化 ≈12ms 晨间）  推断
  │   ├ xrepl/main.rkt：trace self 74.7ms（initialize-namespace → namespace-require → phase-1 visit：
  │   │   实例化 734−244=490 次、faslin-code +23ms、resolver +11ms、requires +3.6ms 为其主体）             推断
  │   └ compile-linklet ×18 = 3ms（REPL 初始化时 eval 的小表达式）                                       已验证
  ├ 关窗：(set-startup-gc-mode! #f 'static) → 一次 major 0–4 → static：29ms @170ms，堆 130MB，释放 24MB   已验证
  └ read-eval-print-loop（expeditor）→ `> `                        ttp 默认 213–224ms；-q 120–124ms（已验证，负载 4–8）
```

窗口内 GC（默认 REPL，到提示符）：15 次 min0 共 ≈19ms（每次 1–2ms，堆 59→128MB）+ 关窗 major 29ms = 48ms，16 次；提示符处 CPU 209ms。（C2 前同机同条件：23 次 / 55ms。）已验证

分层分配（`-n -q` 探针，alloctrace）：racket/base +15.0MB/15ms、racket +71.8MB/63ms（gc 16 次）、racket/init +3.8MB/3ms、首次展开（phase-1 visit）+38.4MB/49ms（gc 28 次）、交互 +5.5MB；major 后存活 100.1MB。已验证

## 2. 各阶段设计与数据结构

| 阶段 | 代码位置 | 核心结构 | 要点 |
|---|---|---|---|
| boot | cs/c/boot.c, ChezScheme vfasl | 三段 vfasl 镜像直接落 static 代 | 固定 25–29ms，不在本轮范围 |
| resolver | expander/boot/handler.rkt、eval/collection.rkt、common/module-path.rkt | mpi（module-path-index，resolved 字段缓存）、path-cache（弱表 按注册表）、collection links 表 | 每次 `module-path-index-resolve` 先查 mpi 自身缓存，未命中才进 resolver；2844/6662 次调用中大部分是跨模块对同一 lib 的首次解析与 `(submod ..)`、相对路径；find-col-file 对每个 collection path 逐个 `directory-exists?`，再 `file-exists?` .rkt / compiled/*.zo |
| load handler | expander/boot/load-handler.rkt | Racket 文件端口；`D` 目录则 search-directory 二分 seek 到子 bundle | 一个模块 = 一次 open + 头解析 + （D）若干 seek；cached-bundle（模块缓存按 sha1）仅对同进程重复声明生效 |
| bundle 读 | cs/linklet/read.ss | `(hasheq key → linklet/值)`；linklet 记录：code(slice→procedure)、literals、format、preparation、importss-abi、exports-info、name、importss、exports | R1：code 不再拷出；adjust 一次 make-linklet；stx-data 与 phase≥1 的 code 拷出以免留住整个 code area |
| 声明 | expander/eval/module.rkt、compile/serialize.rkt | `module` 结构（self mpi、requires、provides=hasheqv phase → hasheq sym → binding、language-info、…）、decl/data/stx-data 实例 | decl linklet 体是生成代码，调用 deserialize 解一个向量编码；D2 把 `#:hasheq`/`#:hasheqv`/`#:hasheqv/phase+space` 解成双向量后一次建 HAMT；D1 把 stx-data 换成代理实例 |
| 实例化 | expander/eval/module.rkt (instantiate-module)、cs/linklet.sls | namespace（phase → module-instance）、instance（符号→variable 记录）、variable（值+常量模式） | body linklet 以 import 实例的 variable 列表为参数被调用；stx 实例每 phase 一份；phase-1 visit 由首次展开触发（xrepl 初始化即触发） |
| 代码物化 | cs/linklet.sls eval-from-bytevector、ChezScheme/c/fasl.c | code-slice → 定位 bytevector 端口 → fasl-read（LZ4 解压到线程复用缓冲 DSTBV）→ 一个 fasl 对象（procedure 或 interpret 向量）；code、reloc 表、闭包、常量出生 gen 1（窗口内） | 年轻引用根表（S_G.young_ref）：读完登记，下次 GC 整对象 sweep 后丢弃 |
| GC | cs/rumble/memory.ss collect/report、ChezScheme/c/gc.c | 窗口：请求一律 (collect 0 1 1)、计数器冻结、无 major 触发；关窗 (collect 4 'static 'static) | 窗口内存活一次拷贝（gen0→1，C2 后 fasl 产物免拷）；关窗把全部存活（~100MB 中的 gen 0–4 部分）拷到 static |
| 交互层 | collects/racket/interactive/tstring.rkt、pkgs/xrepl-lib、expeditor | tstring 读取器、语法着色词法器链、xrepl 命令表与键绑定、expeditor 终端状态 | 两者的 trace self 合计 157ms 含其触发的 visit/装载（与语言层重叠计数），净增 ≈ 90–100ms |

## 3. 数据流与格式

### 3.1 磁盘：.zo
```
"#~" vers-len(1) vers vm-len(1) vm(=tarm64osx) tag
tag 'B': sha1(20) bundle
tag 'D': count(4) + 目录 b-tree 项 {name-len(4) name offset(4) size(4) left(4) right(4)}… + 各 bundle（"#~" 头 + 'B'）
bundle（R1 后）: len|0x80000000(4) fasl(len) codelen(4) code-area(codelen)
  fasl = Chez fasl 流（fasl-type-fasl 条目，压缩标志按 compress-data?=#f 未压缩）：
    key/value 平铺列表 (decl #(#%linklet (off . len) literals format preparation importss-abi exports-info name importss exports)
                       data #(…) stx-data #(…) stx #(…) 0 #(…) 1 #(…) … pre (子模块名…) post (…) name sym side-effects … hash-code sha1)
  code-area: 各 linklet 的 code 依次拼接；每个 code = 独立 Chez fasl 流（头 + 1 个条目，LZ4 压缩，kind 'load'），
             解出恰一个对象：'compile 格式=procedure（外层 thunk，调用得 linklet lambda），'interpret 格式=向量（8 个大 linklet）
  literals: racket/fasl 编码的向量（路径、关键字、pvector 等非 Chez 原生字面量），fasl-read 时作 externals 由 graph-ref 引用
```
启动集 332 文件 15.39MB：code 10.3MB（压缩）、外层结构 ≈3MB（符号 60K/对 82K/其他 40K 对象）、字面量 0.12MB。未压缩代码实测 38.5MB、读取更慢，已否决。

### 3.2 读入后：bundle → linklet 记录
- `read-linklet-bundle-hash`：`(hasheq 'decl linklet 'data linklet 'stx-data linklet 'stx linklet 0 linklet 1 … 'pre … 'name …)`。
- linklet.code：`code-slice{bv start len}`（decl/data/stx/phase 0）或拷出的 bytevector（stx-data、phase≥1）；preparation 'faslable（read-on-demand-source 开时）→ eval-linklet 变 'lazy → 首次 instantiate 时 eval-from-bytevector → 'callable（procedure）。
- importss-abi / exports-info：编译期已知信息（常量/一致性模式、arity），fasl 内嵌；exports-info 按需 unfasl。
- 字面量：bytevector → unfasl-literals/lazy（schemify 层，Racket fasl 解码）→ 向量，作 externals 传给 fasl-read。

### 3.3 声明：decl 数据的编码（compile/serialize.rkt）
- decl linklet 导出 `deserialize` 调用所需数据：一个 `vec` 向量 + 共享表 `shared`；解码器 `decode` 按位置读 tag：`#:ref i`（共享项）、`#:inspector`、`#:bulk-binding-registry`、`#:syntax content ctx srcloc`、`#:datum->syntax`、`#:syntax+props`、`#:srcloc`、`#:quote v`、`#:mpi i`（data 实例的 mpi 向量）、`#:box`、`#:cons`、`#:list/#:vector/#:pvector n …`、`#:hash/#:hasheq/#:hasheqv n k v …`、`#:hasheqv/phase+space n …`、`#:set…`、`#:prefab`、`#:scope`、`#:multi-scope`、`#:bulk-binding`、`#:module-binding …`（nominal-module、phase、sym、extra）、…
- 产物：provides（hasheqv phase+space → hasheq sym → module-binding 记录，D2 批量建表后 4698 项 236KB）、requires（phase → mpi 列表）、language-info、self mpi、submodule 名、`cross-phase-persistent?` 等 → `module` 结构 → `declare-module!` 进注册表。
- 每导出项仍 ≈3.9KB 分配（102→95MB/23736 项），其中 binding 记录 ≈96B + 解码过程 values/vector 临时对象 + 共享表。再导出（67%）各自一份 binding（nominal-module 不同，D3 不可共享）。

### 3.4 stx-data / stx（语法字面量）
- stx-data linklet（每声明一份，跨实例共享）：`deserialized-syntax-vector` = box，`deserialize-syntax` = lambda(bulk-binding-registry) 生成代码：解码 `#:syntax …` 向量 → scope/binding 对象 → box-cas! 发布 → set! 自身 #f。D1 代理：声明时只装 box + 代理 lambda，首次 force 才 eval+instantiate 真 linklet（默认 REPL 到提示符 100/383 个被触发）。
- stx linklet（每实例每 phase）：`(make-vector N #f)` 字面量向量 + `get-syntax-literal!`：命中直接返回，否则 force-syntax-object → 反序列化向量取第 pos 项 → phase shift + mpi shift + inspector → vector-cas! 写回。

### 3.5 实例化 ABI
- `(instantiate-linklet linklet import-instances target-instance)`：对每个 import 实例按 importss 取 variable 记录（extract-imported-variabless，按 importss-abi 判常量可直接取值），对 exports 在 target 实例建 variable（create-variables），然后 `(apply code variable-reference imported… exported…)`。
- 实例 = `instance{name data hash: sym → variable}`；variable = `{val name constance inst}`；常量导入可内联为直接值，否则 variable-ref/check-undefined。
- 模块实例化顺序：requires 递归（phase 0），每模块一份 module-instance{namespace phase-level-array…}；phase-1 visit 由展开触发，按需实例化 for-syntax 依赖。

### 3.6 内存与 GC 的对应（窗口内）
| 产物 | 分配者 | 代/空间 | 最终去向 |
|---|---|---|---|
| bundle 外层结构（键列表、linklet 向量、符号） | fasl-read（Racket 端口 bstr + Chez fasl） | gen 0 | 用后垃圾（符号留 oblist） |
| code area bytevector | read-bytes | gen 0 | 被 slice 引用直到 eval；拷出的 stx-data/phase≥1 片 |
| code 对象、reloc 表、闭包、字面量常量 | faslin（C2） | gen 1：space_code / data / closure / impure | 关窗 major → static |
| 字面量向量（racket/fasl 解码） | Racket | gen 0 | 关窗 → static |
| module 结构、provides HAMT、binding、mpi、namespace、instance、variable | expander/rumble | gen 0 | min0 拷到 gen 1 → 关窗 → static |
| 语法对象（scope、syntax 记录） | deserialize（按需） | gen 0 | 同上 |
| 解压缓冲 DSTBV/SRCBV、fasl strbuf、graph 表 | fasl 读 | gen 0（线程复用/临时） | 垃圾 |

## 4. 开销账本（默认 tty REPL，到提示符，已验证）

| 项 | 数值 |
|---|---|
| 读入字节 | 15.39MB（332 文件）+ 交互层模块 |
| expander eval 分配 | 150.7MB（instantiate 98.0、resolver 21.9、module 20.0、requires 10.3）；read 26.1MB |
| CPU 到提示符 | 209ms；其中 expander eval 121.8ms（instantiate 57.0、resolver 36.4、module 20.1、requires 7.8）、read 14.4、linklet 层 total 127[+16]（read 55 含 faslin-code 42、run 39、boot 26） |
| GC | 16 次 48ms（15 min0 19ms + 关窗 major 29ms）；堆峰值 130MB，关窗释放 24MB |
| 存活 | major 后 100.1MB（-q 探针）；footprint 127–131MB |
| 墙钟 | 213–224ms（pty，`> ` 出现） |

## 5. 未测 / 未知

- resolver 25–36ms 的构成：2844/6662 次调用，日期 stat 已排除；`(lib ..)` 字符串解析、collection path 探测次数、path-cache 命中率、注册表查找各占多少——**未知**（需按子步骤插桩）。
- instantiate 57ms（默认）中：变量创建/导入提取 vs 模块体执行 vs stx 实例化——晨间探针仅给出体执行 6–7ms；phase-1 visit 部分的 490 次实例化成本分布——**推断**。
- tstring.rkt 82.8ms / xrepl 74.7ms 的 self 与语言层区域的重叠划分——**推断**（晨间 loadtrace2：phase-1 visit 50、词法器链 29、expeditor 12）。
- faslin-code 42ms 中 fasl 解码 45%/LZ4 21%/intern 13% 来自 `racket -q` 集合的离线采样，默认 REPL 的 phase-1 代码未单独采样——**推断**。
- 关窗 major 29ms 拷贝了什么：堆 130MB 释放 24MB → 拷贝 ≈ 存活中非 static 部分；C2 后 gen 1 的 fasl 产物仍被拷——**推断**（量未分离）。
- 外层 bundle 的 60K 符号 intern 与 82K 对的构建（fasl-bundle 8ms）中可省的份额——**未知**。
