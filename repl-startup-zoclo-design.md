# zoclo 通道设计文档：跨进程 fasl 迁移中的 0-fv 闭包身份分裂

> 面向"第四 boot 段（REPL 预实例化）"工程的专项设计文档。2026-09-15 定稿。
> 上位文档：`repl-startup-4th-segment-handoff.md`（§2.3 外置通道表、§7.1）。
> 流水账：`repl-startup-kernel-enhancement-plan.md`（2026-09-15 D111-D124 条目）。
> memory 索引：`racket-repl-startup-project.md`。
> 结论分档：**已验证**（有实测数据）/ **推断**（有间接证据，写明缺口）/ **未知**。

---

## 0. 摘要

段协议把 racket/init + xrepl 实例化后的 namespace 状态序列化为"第四 boot 段"，B 进程反序列化恢复，跳过语言层重实例化。协议对机器码对象（code）走"不进段、B 重放同名 .zo"的通道。本文档描述的缺陷是：**一类不带自由变量的闭包（0-fv 闭包），在 zo 装载进程上与其 code 的 relocation 自字面量是同一个堆对象；段迁移后在 B 上分裂为两个 `eq?` 不等的对象**。任何以闭包对象本体作 `eq?` 键的机制（stxparam 的 continuation-mark 键是典型）因此失效，表象为 class 族 `super-new` 报 "use of a class keyword is not in a class"。

修复是新增 **`'zoclo` 外置通道**：A 端把符合条件的 0-fv 闭包外置为其 code 的 `(事件号 . 序号)`，B 端解析为重放 code 的 reloc 自字面量，使 B 上 cell 引用与 reloc 引用重新指向同一对象。

**状态（已验证）**：配方线（`RACKET_RETAIN_STATIC_RELOC=1` + `P33_LIBID=1`）6 对连续全绿——核心 11/11 VERDICT(A) + 扩展 12/12 fail=0，命中 3 条全 ok、0 MISS。消融证明单此一项即令扩展满分。**§6 三缺口已于 2026-09-15 全部封闭（D125-D127）**：MISS 致命（故障注入实测炸）、A 端往返自校验、staddr/dwseq 互斥断言；封闭后 3 对整对回归全绿。

---

## 1. 背景

### 1.1 段协议对 code 对象的处理（既有机制回顾）

- **A 进程**（`P33_ROLE=A`）：racket -q -n 启动到 mark 点后，`namespace-require racket/init`，期间用 `current-load` 拦截每次 .zo 装载，记录事件清单（路径 + 该文件产出的 code 计数），写入 `seg4z-zolist.fasl`。code 对象**不进主段**。
- **B 进程**（`P33_ROLE=B`）：读取事件清单，**重放同一批 .zo 装载**（fasl 解码，不实例化），得到自己的 code 对象表。段图里闭包的 code 指针以 `(事件号 . 序号)` 名字（tag `zo`）跨进程解析到 B 表的对应项。

该通道的正确性前提是**zo 重放逐字节确定**：同一 .zo 字节序列在 A/B 装载出结构同构的 code 表，(事件号 . 序号) 是稳定的跨进程名字。这是整套协议的既有 load-bearing 假设，probe9（见 §3）给出 code 身份解析正确的一个数据点。

### 1.2 现象

- 微实验：裸 `(syntax-parameterize ([P ...(_) 'inside]) (P))` 在 A 上返回 `'inside`，在 B 上返回 `'default`。
- 下游：`(class object% (super-new) ...)` 在 B 上报 `super-new: use of a class keyword is not in a class`。这是灾前扩展诊断的唯一残余，跨绿基线/配方线都在。

---

## 2. 根因：0-fv 闭包身份分裂

### 2.1 概念前置

四个 Chez Scheme 底层概念，后文反复引用：

| 概念 | 定义 |
|---|---|
| **code 对象** | 机器码对象（`$code?` 为真）。带一张 **relocation 表**（reloc 表）：机器码指令引用的所有堆对象（符号、字符串、其他 code、闭包）都登记在此，供 GC 移动后回写指针。等价于该函数机器码的常量池。读取用 `(cs)s_get_reloc` foreign-procedure（本工程封装为 `dw-get-reloc`）。 |
| **闭包对象** | Chez 过程值，结构 = code 指针 + 自由变量槽 fv0..fvN。`$closure-length`（封装 `safe-clen`）返回槽数。**0-fv 闭包** = 槽数为零，整个对象只有一个 code 指针。 |
| **变量 cell** | CS 的 linklet 实例（`instance` 记录，字段 = name/data/hash）为每个模块级变量维护一个 `variable` 记录，字段 0 是当前值。跨模块引用在运行期即"读被引模块实例中该名字的 variable 记录字段 0"。下文"cell 版"指此路径取到的值。 |
| **reloc 自字面量** | 对模块级、0-fv、且函数体内引用了自己的函数 `f`（形如 `(define (f) ... f ...)`），编译器不为自引用分配自由变量槽，而是把 **f 的闭包对象本身**作为常量放进 f 的 code 的 reloc 表。 |

### 2.2 正常进程：cell 与 literal 是同一个对象

装载 .zo 时，fasl 装载器创建 code 对象的同时创建这个自字面量闭包，并把**同一个对象**写进实例的变量 cell。所以在任何单一进程里：

```
                       code 对象 cd
                      ┌──────────────┐
   实例 cell ─────►   │  机器码 ...   │
        │             │  reloc 表:    │
        │             │   [..., ●] ───┼──┐
        ▼             └──────────────┘  │
   闭包对象 F  ◄─────────────────────────┘
   （cell 与 reloc 表指向同一个 F）
```

"读 cell 取 F"和"执行 cd 的机器码、其中对自身的引用取 reloc 表里的 F"殊途同归，都是 F。

### 2.3 段旅行如何把 F 一分为二

段协议对 code 与闭包的处理不对称：

- **code 不进段**：B 靠重放 .zo 得到自己的 `cd_B`。装载 `cd_B` 的**正常 fasl 流程又创建了一个 reloc 自字面量闭包 `F_lit`**，挂在 `cd_B` 的 reloc 表里。
- **闭包本体进段**：A 实例 cell 里的 F（A 装载该 .zo 时创建的）作为段图普通节点被序列化，B 反序列化出一个新堆对象 `F_cell`。

结果 B 进程里同一个 code 对应**两个** 0-fv 闭包：

```
   B 进程                        code 对象 cd_B（zo 重放得到）
                               ┌──────────────┐
   段图 ──► 实例 cell ──► F_cell │  机器码 ...   │
                               │  reloc 表:    │
                               │   [..., ●] ───┼──► F_lit
                               └──────────────┘
   F_cell ≠ F_lit （eq? 为 #f，这是 A 上从不存在的分裂）
```

- `F_cell`：段带来的、A 实例 cell 里那个闭包的副本 → 服务一切 racket 层变量引用。
- `F_lit`：B 重放 zo 时新造的 reloc 自字面量 → 服务该函数机器码内部的自引用。

A 上 `F_cell` 与 `F_lit` 本是同一对象 F，故 A 一切正常。

### 2.4 stxparam 为何恰好踩中

`racket/collects/racket/private/stxparamkey.rkt`（源码原文）：

```racket
(define (current-parameter-environment)
  (continuation-mark-set-first #f current-parameter-environment #hasheq()
                               (unsafe-root-continuation-prompt-tag)))
```

关键：continuation-mark 的**键就是 `current-parameter-environment` 函数对象本身**（第二个实参）。语法参数环境整个建立在"用该闭包对象当 mark 键"上，而 mark 键匹配语义是 **`eq?`（指针同一性）**。

- **写侧**：`syntax-parameterize` 的展开器（`private/stxparam.rkt` 的 `let-local-keys`）展开期执行
  `(with-continuation-mark current-parameter-environment (extend-parameter-environment ...) (local-expand 体 ...))`。
  这里 `current-parameter-environment` 是**模块级变量引用** → 经 cell 取值 → 取到 **`F_cell`**。mark 以 `F_cell` 为键写入。
- **读侧**：展开 `(P)` 时经 `prop:set!-transformer` → `apply-syntax-parameter` → `syntax-parameter-key-value` → **调用** `current-parameter-environment`。被调用的对象也是 `F_cell`（同样从 cell 取），但它执行的是 `cd_B` 的机器码，其中"以自己为键"的那处引用被编译成**从 reloc 表取常量** → 取到 **`F_lit`**。

### 2.5 失败因果链

```
F_cell ≠ F_lit (eq? #f)
  → 写侧以 F_cell 为键写 mark，读侧 continuation-mark-set-first 用 F_lit 搜
  → 搜不到 → 返回默认空表 #hasheq()
  → syntax-parameterize 建立的绑定全部不可见
  → super-new 这个 syntax parameter 读到默认 transformer（not-in-a-class 分支）
  → "use of a class keyword is not in a class"
```

class 只是最显眼的下游用户；机制层面**所有 syntax parameter 都断**。

---

## 3. 证据链（探针）

全部在 B 端 15 秒级迭代取得（段产物复用，`run-stxb.sh` 只跑 B）。探针群 `P33_STX=1` 门控，永久装备于 `p3.3b.chez.ss` 与 `p3.naming.ss`。

| 探针 | 内容 | 结果 | 排除/结论 |
|---|---|---|---|
| 微实验 | 裸 syntax-parameterize 期待 'inside | B='default | 现象复现 |
| peek-env | syntax-parameterize 体内 transformer 直接调 `(current-parameter-environment)` 数条目 | B=`((0 default) 0)` (A=`((1 inside) 0)`) | 写入的环境读侧不可见 |
| probe2 | 同一 transformer 内、同一变量取的键，自 wcm 写、自经函数调用读 | B=0 | **排除"写读来自不同模块实例"**——同键写入仍读不到，断点在函数内部的读 |
| probe3/4/5 | phase-0 裸 wcm；显式 root-tag 读；phase-1 用新造 gensym 键 | 全部正常 | wcm / cmsf / prompt-tag 定界 / phase-1 执行环境各层无恙 |
| probe7/8 | 以 F_cell 为键写，B 本地 `continuation-mark-set-first` 直读（无 tag / 带 B root tag） | 都读到 | **写入无恙、F_cell 作键无恙**——函数内部读用的必是另一个键对象 |
| probe9 | cpe 的 code 在 B 的 zo 表位置；同名 code eq | (32 . 1)，YES | code 身份解析正确（zo 通道无恙） |
| probe6 | cpe 闭包 clen / code-name / code 的 generation | clen=0，name=current-parameter-environment，gen=4 | 目标是动态代 0-fv 闭包 |
| probe10 | `dw-get-reloc` 转储该 code 的 reloc 表（7 项） | cmsf/root-tag 访问器走 gensym 库全局（B 本地）；表内有一个 clen=0、code 指向自身的闭包 | **排除"冻结 A 的 cmsf/root tag"假说**；定位 `F_lit` |
| probe11 | `(eq? F_lit F_cell)`；以 `F_lit` 为键写 mark 后调 `F_cell` 读 | eq=#f；读到（=1） | **终审**：函数内部读的键正是 `F_lit`，两对象分裂即全部现象的充要解释 |

reloc 转储可安全读取的依据（已验证）：目标是 init 期 zo 装载产生的**动态 generation（gen 4）** code，其 reloc 表受 GC 维护；不受配方线 `retain` 下"静态 reloc 表 GC 不更新会悬垂"的限制（那只针对 static-generation code）。

---

## 4. 设计：`'zoclo` 外置通道

### 4.1 通道语义

- **命名**：外置为该闭包所属 code 的 `(事件号 . 序号)`（与 `zo` 通道同一命名空间，复用 `zo-a-lookup` / `zo-b-lookup`）。
- **canonical target 的唯一性论证**：可选的规范对象有二——`F_cell` 或 `F_lit`。二者作为可调用值完全等价。但读侧（get）对函数自身的引用**烧死在机器码的 reloc 里，无法改写**；写侧（cell）可以改指向。所以规范目标只能选 **`F_lit`**，这是被逼出的唯一解，不是任选。B 端把 cell 引用也解析到 `F_lit`，令两条路径重归一致。

### 4.2 共享 helper：`p33-zoclo-literal`（`p3.naming.ss:1172`）

```scheme
(define (p33-zoclo-literal cd)
  ;; -> cd 的 reloc 里那个 0-fv 自字面量闭包，或 #f
  ;; （动态代 code 的 reloc 受 GC 维护，任何时候读都安全）
  (let ([rl (try (lambda () (dw-get-reloc cd #f)) '())])
    (let loop ([l rl])
      (cond
        [(not (pair? l)) #f]
        [(and (procedure? (car l)) (not ($cont? (car l)))
              (eqv? (safe-clen (car l)) 0)
              (eq? (try (lambda () ($ccode (car l))) #f) cd))
         (car l)]
        [else (loop (cdr l))]))))
```

**唯一性**：结构上一个 code 的 reloc 里只有一个"自字面量"（0-fv 且 `$ccode` 指向自身），返回它，唯一。`(eqv? (safe-clen ...) 0)` 中 `safe-clen` 失败返回 #f，`(eqv? #f 0)` 为 #f，非闭包/失败项被跳过。

### 4.3 A 端规则（`p3.3a.chez.ss:355`）

加在规则链**末尾**（pre-boot-marked 之后）：

```scheme
(add-rule! 'zoclo
           (lambda (v)
             (and (procedure? v)
                  (not ($cont? v))
                  (eqv? (safe-clen v) 0)
                  (not (eq-hashtable-ref mark-ht v #f))
                  (let ([cd (try (lambda () ($ccode v)) #f)])
                    (and cd
                         (zo-a-lookup cd)
                         (eq? (p33-zoclo-literal cd) v)))
                  #t)))
```

四条守卫，缺一不可：

1. `0-fv 闭包`（procedure ∧ 非 continuation ∧ clen=0）。
2. `非 mark 域`（不在 `mark_ht`）——mark 域对象走 pre-boot-marked/loc 通道，且分裂问题只存在于 init 期 zo 装载的对象。
3. `code 有 zo 名`（`zo-a-lookup cd` 成功）——保证 cd 是动态 zo 代，B 能重放出对应 code；连带保证 `p33-zoclo-literal` 只读动态代 reloc（安全）。
4. **`A 上 cell 闭包 == 自身 reloc 字面量`**（`(eq? (p33-zoclo-literal cd) v)`）——**语义保真的核心判据**：只有当替换在 A 语义下是恒等变换时才外置。

### 4.4 A 端 spec 生成（`p3.3a.chez.ss:568`）

```scheme
[(zoclo)
 (let ([hit (zo-a-lookup ($ccode x))])
   (vector 'zoclo (car hit) (cdr hit)))]
```

### 4.5 B 端解析（`p3.3b.chez.ss:369`）

```scheme
[(zoclo)
 ;; canonical 0-fv 闭包 = 重放 code 的 reloc 自字面量
 (let* ([c (zo-b-lookup (vector-ref e 1) (vector-ref e 2))]
        [lit (and c (p33-zoclo-literal c))])
   (cond
     [lit (vector-set! extvec i lit) (vector-set! resolved i #t)
          (bump! 'zoclo 'ok)]
     [else (bump! 'zoclo 'MISS)]))]
```

### 4.6 数据流全貌

```
A 端                                          B 端
─────                                         ─────
mark 点后 racket/init                          重放同批 .zo → cd_B, F_lit
  ↓ zo 拦截 → zo-a-tab: cd → (evt . seq)
写循环遇 0-fv 闭包 v:
  规则守卫 1-4 全过（v == A 的 F_lit）
  spec = (vector 'zoclo evt seq)  ────段manifest───►  解析 (evt seq):
                                                        c = zo-b-lookup(evt,seq)  = cd_B
                                                        lit = p33-zoclo-literal(c) = F_lit
                                                        extvec[i] = F_lit
段图里 v 的位置被 external 引用替换                     fasl-read 用 extvec 回填
                                                     → 段图中原 F_cell 位置现指向 F_lit
                                                     → cell 引用与 reloc 引用重归一致
```

---

## 5. 正确性与安全性

### 5.1 核心安全性质（已验证，构造性）

安全根基是守卫 4（`(eq? (p33-zoclo-literal cd) v)`）。据此三条可证性质：

1. **保守性**：不满足守卫的闭包一律不外置，退回原图内旅行。失败模式不劣于修复前。
2. **单调保真**：修复前 B 上 `F_cell ≠ F_lit`（A 上从不存在的伪分裂）；修复后 B 上二者重归一。该通道**消除**一个伪分裂、不制造新分裂——因为 A 上 `F_cell == F_lit`，A 曾有的任何 `eq?` 关系（"某对象 eq 于 F_cell"）同时也是"eq 于 F_lit"，B 端指向规范 `F_lit` 后这些关系全部保持。方向朝更高保真。
3. **行为等价完全**：两个 0-fv 闭包共享同一 code，作为可调用值完全可互换（调用哪个都是无捕获环境地跑同一段机器码）。唯一可观测差异就是 `eq?` 身份，而正规化只改身份、不改行为。

### 5.2 信任边界（已验证）

**无新增攻击面**。整条链路消费本机构建的可信 boot .zo（系统自身 collects）+ 本工具自产的段文件。真正的反序列化面是 `c-faslr`（能构造任意对象），在 zoclo 之前就存在；段文件本就是可信输入。zoclo 只改变某外置槽解析到**哪个可信对象**，不改变信任边界。若段文件哪天成为不可信输入，整套方案（不止 zoclo）都不成立——非 zoclo 引入。

### 5.3 消融（已验证）

去掉先前的 `'#%unsafe` / `'#%paramz` 扩根尝试（第一版假说 = root prompt tag 单例逃逸，probe10 已证伪），仅保留 zoclo 单项，扩展仍 12/12、6 对稳定。最终配方 = 纯 zoclo。

---

## 6. 已知缺口与加固计划

> **2026-09-15 更新：三缺口已全部封闭（D125-D127）。** 加固全部只动失败路径；封闭后 3 对整对回归全绿（核心 11/11 + 扩展 12/12 + zoclo 3 ok / 0 MISS，A 端两断言零触发）。各小节保留原分析，末尾追加落地记录。

三个缺口均在**失败路径的可见性/护栏**上，不在 happy path 正确性上。产品化（§7）合主线前应封。

### 6.1 缺口 1（已封，D125）：zoclo MISS 是静默 #f 注入

B 端 dummy-code 兜底循环（`p3.3b.chez.ss:546`）只覆盖 tag：
`'(code code-unwalked codeloc zo zomiss zoloc bdw cpb)`。**`'zoclo` 不在此列**。故 zoclo MISS 时 `extvec[i]` 保持初值 #f，`c-faslr ... 'load extvec` 会把 **#f 拼进本该是闭包的位置** → 该闭包被调用时 "not a procedure"，或当 mark 键/hasheq 键用时行为诡异。静默腐化，非响亮报错。

- 现状：实测 3/3 命中、0 MISS，未触发。
- 注：非 code 家族 tag（rtd/kw/rmp/staddr/dwseq/iscope/prefab）MISS 都是同样的 #f 注入；设计隐含假设"非 code 外置永不 MISS"。zoclo 归入该阵营，但作为新通道，此假设对它只有本轮 3 条数据背书。
- **加固**：resolver MISS 分支改致命（abort 段安装 + 打印槽位）。zoclo 语义上不该 MISS，MISS 即协议破裂，应炸。
- **落地（已验证）**：MISS 分支记样本（槽位 i / evt / seq / 是否有 code），census 打印后、dummy 布线与 fasl-read 之前 `FATAL + exit 1`（`p3.3b.chez.ss:347/370/529`）。放循环外是因为 resolve 循环的命名 let 把日志端口变量 `lp` 遮蔽为循环函数，且这样保住完整 census 诊断。**故障注入实测**：evt+100000 强制 3 MISS → B-exit 1 + 三条槽位样本 + 不进 fasl-read；恢复后复绿。

### 6.2 缺口 2（已封，D127）：与 staddr/dwseq 的规则互斥

规则链有序，`rule-tag` 取首个匹配，zoclo 在最后 → staddr/dwseq 平局时抢先。是否会抢走 zoclo 目标？

- **staddr**：要求 `staddr-static?`（generation=7）。zoclo 目标 gen=4（动态，probe6 实测）→ 不匹配。
- **dwseq**：要求在 `dw-obj-seq`，该表由 mark 点（init 之前）dw-walk! 填充；stxparam 闭包 init 期（mark 之后）才产生 → 不在表内 → 不匹配。

当前配置下二者与 zoclo **不相交**，依据 generation(4≠7) + walk 成员性（post-mark 不入 dw-obj-seq）。**但这是推理，非代码断言**。若将来 dw-walk 改到 post-init，或出现既 gen-7 静态又 zo-literal 的 0-fv 闭包，可能重叠，届时 staddr/dwseq 按地址/walk 序解析、不一定到规范 literal。

- **加固**：对 zoclo-tagged 对象断言不同时匹配 staddr/dwseq 谓词（或前移 zoclo 并显式排除）。
- **落地（已验证）**：新 helper `p33-zoclo-target?`（`p3.naming.ss:1185`，zoclo 规则的对象侧本质，去 mark-ht 守卫）；A 端 manifest 构建的 staddr/dwseq 分支若捕获满足该谓词的对象即 `FATAL + exit 1`（`p3.3a.chez.ss:569/583`）。断言方向 = 偷取方向（first-match 下 zoclo-tagged 必已过不了前序规则，只有前序偷 zoclo 目标需检）。快速守卫前置（procedure/clen=0/zo-a-lookup），boot-static 闭包的 code 不在 zo-a-tab，reloc 读不触发，成本可忽略。3 对回归中随每条 staddr/dwseq 项执行，零触发。

### 6.3 缺口 3（已封，D126）：正确性挂 zo 重放确定性

A/B 各算 `p33-zoclo-literal cd`（取该 code reloc 里第一个自字面量）。两侧对应，前提是 B 的 zo 重放逐字节确定，使 reloc 表结构与 A 同构、"第一个自字面量"选到对应对象。这是全协议既有前提（probe9 一个数据点），zoclo 对它无独立门禁。

- **加固**：A 端往返自校验——每条 zoclo 外置后立刻用 A 自己的 reloc 重解析，断言 eq 回 v。近零成本，把"zo 确定性"从假设升级为构建期不变量。
- **落地（已验证）**：`p3.3-table.chez.ss` 保留 per-event code 向量（`zo-a-codevecs`:10）+ 反查 `zo-a-ref`（:37，zo-b-lookup 的 A 端镜像）；spec 生成时 `(evt . seq)` 经 A 自己的事件表索引 + `p33-zoclo-literal`——恰是 B 将走的两步——断言 code eq 且字面量 eq 回 x，失败 `FATAL + exit 1`（`p3.3a.chez.ss:589-608`）。校验的是 A 端命名往返（事件表索引完整性 + manifest 时点的守卫 4 重验，晚于规则匹配时点、跨过其间 GC）；B 侧重放与 A 同构仍靠既有前提，但两侧各自的"名字→字面量"解析路径已同构受检。3 对回归中随 3 条 zoclo spec 执行，零触发。

### 6.4 同 code 多闭包（已验证，无问题）

守卫 4 要求 `v` eq 于 `p33-zoclo-literal cd`（返回唯一对象），每个 code 至多一个闭包过关。同 code 的其它 0-fv 闭包（若存在，如非 interned 的重复实例化）过不了守卫，退回图内旅行——安全兜底；它们在 A 上本就是与 literal 不同的对象，B 上作为副本保持区分，无新 `eq?` 失配。

---

## 7. 产品化清单接口（§7.3 补项）

合主线前，除上位 handoff §7.3 既有项外，zoclo 相关：

1. 缺口 1「MISS 改致命」——**必做**（静默腐化风险最实）。**已做（D125，故障注入实测）**。
2. 缺口 2/3 的自校验/断言——**建议**（防未来回归，把两条前提变成受检不变量）。**已做（D126/D127，3 对回归零触发）**。
3. code 通道产品化（zo 重放 → 内核 closure-fasl 原生 code）落地后，zoclo 的命名基座（zo-a/b-lookup）随之改写；zoclo 的判据（0-fv ∧ 自字面量）不变，只是命名从 (evt.seq) 改为 code 的原生 fasl 名。
4. **普适性备忘**：任何跨进程 fasl 迁移方案，凡"以闭包对象本体做 `eq?` 键"的机制都受 0-fv 字面量分裂制约（与 h7 eq-hash-code 同级，属"对象身份跨进程保持"类问题的第二个实例）。新增此类机制时须复核是否需要 zoclo 式正规化。

---

## 8. 速查

### 8.1 代码位点

| 组件 | 文件:行 |
|---|---|
| `p33-zoclo-literal`（共享 helper） | `p3.naming.ss:1172` |
| `p33-zoclo-target?`（互斥断言谓词，D127） | `p3.naming.ss:1185` |
| A 端规则 `'zoclo` | `p3.3a.chez.ss:355` |
| A 端 staddr/dwseq 互斥断言（D127） | `p3.3a.chez.ss:569/583` |
| A 端 spec 生成 + 往返自校验（D126） | `p3.3a.chez.ss:589` |
| A 端反查表 `zo-a-codevecs`/`zo-a-ref`（D126） | `p3.3-table.chez.ss:10/37` |
| B 端解析 + MISS 样本（D125） | `p3.3b.chez.ss:370` |
| B 端 zoclo MISS 致命块（D125） | `p3.3b.chez.ss:529` |
| dummy-code 兜底 memq 列表（zoclo 故意不在此列，MISS 走致命） | `p3.3b.chez.ss:565` |
| 探针群（peek-env / probe2-11） | `p3.3b.chez.ss`（P33_STX=1 门控）、`p3.naming.ss`（p33-stxkey-dissect / p33-fv-hunt-cpe / p33-hunt-ptags / p33-find-cpe-closure / p33-collect-insts / p33-inst-vartab） |

### 8.2 关键事实

- `current-parameter-environment` code 在本轮 B 的 zo 表位置 `(32 . 1)`；generation=4（动态）。
- zoclo 命中 3 条（本轮实测），全 ok，0 MISS。
- reloc 读取：动态代 code reloc 受 GC 维护，post-GC 安全，不受 retain 静态 reloc 悬垂限制。
- continuation-mark 键匹配语义 = `eq?`；这是 0-fv 分裂能致命的直接原因。

### 8.3 探针纪律（本轮血泪，已实测）

- 字面 `#%unsafe` token 会炸 Chez reader（装载驱动即死）；运行期须 `(string->symbol "#%unsafe")` 构造 module path。
- engine `try` 的 fallback 按值急求值，只放纯值（放 `(o ...)` 会先打印，再犯一次）。
- 陈日志假象：run 脚本一律先 `rm` 驱动 log，否则崩在装载期时读到上一轮内容。
- 深嵌套区补丁括号漂移两次；strip 字符串/注释后机械平衡检查入固定流程。
