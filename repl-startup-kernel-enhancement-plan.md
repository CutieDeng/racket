# 内核路增强实施规划:fasl 闭包序列化 → REPL 启动零 GC

2026-09-07 · R2 已放行(档B) · 目标=racket/init+xrepl 预实例化进条件装载的第四 boot 段 → 消 ~70ms startup GC + 实例化时间 · 红线=非 REPL 零影响、bit-exact、语义不变

## 阶段划分(每阶段有明确否决门,失败即止损/退务实备选)

### P0 前置验证(只读/小样,全通过才进 P1)——最强否决集,最省
- **P0.1 R2b 补审计**:racket/init+xrepl 全图遍历,重点=xrepl 是否引入 readline/终端端口的**具名捕获**(唯一可能翻盘的架构死点)。复用 R2 遍历器(traverse.head/driver.ss)。否决门:发现本质捕获→内核路死,退备选。
- **P0.2 弱引用 fasl 小样**:~3300 weak-pair/ephemeron 是 fasl 格式不支持的最大工作量。小样验证"剥离缓存+重建不破 intern 语义"可行。否决门:剥离破坏 intern→需重设计。
- **P0.3 常量折叠边界抽查**:语言函数有无把端口/线程焊进常量池(R2 未发现,确认)。

### P1 fasl 闭包序列化内核(Chez c/fasl.c + s/fasl.ss + vfasl)
- P1.1 `wrf`(fasl.ss:678-723)加 procedure 分支:序列化 code-ptr + free-var 向量;R1 往返 bit-exact 单纯 λ 起步。
- P1.2 弱/ephemeron 对的 fasl 处理(丢弃重建/转强引用,依 P0.2 结论)。
- P1.3 vfasl(vfasl.ss)加 closure vspace 布局(参照现有 code 分支)。
- **保障(全程)**:R1 bit-exact 差分电池(枚举 racket/init 全闭包类型)、R3 热路径编译期门控保非 REPL fasl 指令数不变、R4 复用三路评审(裸 SegInfo 清单)。

### P2 外置机制(反序列化后 per-place 重绑,依 R2 外置清单)
- registry lock-box 重置#f(斩 thread/place 子图,最高优先)、root-expand-ctx 复位、参数 thread-cell 默认值 per-place 重播种、place-local 表不序列化 per-place 重建。

### P3 第四 boot 段(条件装载,依 subagent a957 蓝图)
- racket-init.so(demod flatten racket/init+xrepl)→ racket-init.boot(convert-to-boot 前置段+racket)→ racket-init-v.boot(to-vfasl)→ embed-boot.rkt 扩 4 段。
- boot.c 加 Sregister_boot_file 第四段、main.sps 由 REPL 意图条件装载(非 REPL 不映射)、装载后接上预实例化 ns(替 namespace-require+ init-library)。
- **验收硬门**:非 REPL 模式(-e/raco/脚本)内存/实例化数/时间逐项与改前一致(A/B),任一回归即否决。

### P4 验证与评审
- 交互 REPL:实例化数 1792→? / GC 70→~0 / time-to-prompt 200→? min-of-N。
- 全套件回归(pvector.rktl 等)、pb-build、跨 place(place-message 弱引用剥离后语义)。
- 设计评审(三路 subagent):正确性/性能/GC 交互。

## 里程碑与止损
- P0 任一否决门触发→内核路止损,退**务实备选**(GC 旁路 v1 修恢复点 −70ms 不需序列化 + demod 降实例化)。备选始终在位,非 REPL 天然零影响。
- 工作量量级:P1 弱引用 fasl 是主体(Chez 核心);P0 只读1-2天;总体高风险,分阶段否决控险。

## 保障框架引用
R1-R4 详见 repl-startup-preinstantiate-plan.md「风险保障框架」节。方法论=先量再改/否决点前置/每步 bit-exact 差分/改动面隔离/热路径零成本。

## P0.1 R2b 通过:xrepl 无翻盘死点(2026-09-07,subagent af2f)
xrepl 加载后闭图 92673 节点(+13% vs R2 81827),**不可迁移类别 28→28 逐一对齐,零新类型**;**无活终端/readline/expeditor/syntax-color**(grep 零命中)——expeditor/readline 受 terminal-port? 双门保护(=我们那把门刀红利),build 期无tty镜像必不含终端端口。审计边界:审的是"加载xrepl模块"非"expeditor-open活终端",后者只在真tty交互时dynamic-require,不进镜像。
**唯一新增本质捕获**:,shell命令thunk(xrepl.rkt:52 original-input-port=stdin)+,log命令thunk(xrepl.rkt:1365 global-logger=根logger)把值内联进闭包槽。但两者=标准place单例,R2外置清单已覆盖;xrepl只加第二引用未造新对象。修复+1(值内联槽,restore重跑xrepl模块体重捕获,非改data格),影响面窄(错只坏这两交互命令,不碰主干)。
**裁决档B,P0.1否决门通过,内核路仍活**。外置清单追加:xrepl.rkt:52/1365两处,共用"重跑xrepl实例化"修复手法。
**下步 P0.2**:弱引用 fasl 小样(~3300 weak/ephemeron,内核路最大工作量,验证剥离缓存+重建不破intern语义)。P0.3 常量折叠边界抽查。

## P0.2 弱引用 fasl:纠正 subagent 高估,工作量大幅缩小(2026-09-07,读 fasl.ss 源)
**a68c 的"弱引用是 fasl 不支持的最大工作量"是错的**。实证 fasl.ss:
- wrf-pair(fasl.ss:294附近)**已完整序列化 weak-pair/ephemeron-pair**(递归 wrf car/cdr,297-302)。R2b 那 2137 weak-pair+339 ephemeron **本来就能进 fasl**,零工作。
- wrf(678-723)真正拒绝只两类:[(hashtable? x) wrf-invalid](703)+[else wrf-invalid](无procedure分支)=**哈希表+闭包**。
- R2b 弱对象大头来自 intern 表(intern.rkt:box+hasheqv of weak-box,纯缓存,prune-at剪枝,interning幂等)=**可丢弃重建,不需序列化**(=外置清单 caches 类)。
**⇒ P0.2 结论(有利):内核路唯一主体工作回归"闭包/代码序列化"这个已知核心项;弱引用"最大工作量"虚高证伪。** 剩余核实(下会话):确认 intern 哈希表是弱哈希表大头且确可丢弃重建、eq-hashtable-weak(570-571)那条路是vfasl专用还是wrf可达。
**方法论**:又一次读源纠正 subagent 的估计——审计给方向,源码定量,不轻信二手估算(同 openssl 持平"别信记忆基线"教训)。
**P0 门进度**:P0.1✅(xrepl无死点)/P0.2✅有利(弱引用非障碍,主体=闭包序列化)/P0.3待做(常量折叠边界)。P0.3过→启动wrf闭包序列化内核spike(R1-R4保障)。

## P0.3 通过:code 常量池干净,内核路 P0 门全清(2026-09-07,subagent ab5a,实证)
补 R2/R2b 剪枝的 code 常量池盲区。实测 racket/init+xrepl 9293 code 对象/48963 常量(无截断):**无任何活运行时资源折叠进 code**。硬名单不可迁移类型(端口/线程/semaphore/custodian/continuation/weak/cpointer)常量池普查各0次。唯三资源形命中 eq? 实证=永生单例/NULL指针/类型描述符(always-evt/地址0的ftype-pointer/根inspector),皆可迁移。
**结构性结论**:R2 发现的活资源(semaphore36/custodian/thread/fd-port/logger)**只经活闭包/数据cell持有(R2已裁面),code常量池干净**——两持有路径完全分离。fasl构造级安全:s_get_reloc对static-gen code返回nil,活端口/线程无法fasl进.zo/boot→静态代成按构造即安全。
**内核路 P0 前置门全清:P0.1✅(xrepl无死点)P0.2✅(弱引用非障碍)P0.3✅(常量池干净)**。三道只读审计门(R2/R2b全图遍历+code常量池)一致放行,无翻盘死点,工作量收窄到"闭包/代码fasl序列化+per-place外置重绑"核心。
**下步进入 P1:wrf 闭包序列化内核 spike**。P1.1=fasl.ss wrf(678-723)加 procedure 分支(序列化 code-ptr+free-var 向量),R1 bit-exact 单纯λ往返起步;走 R1-R4 保障框架(bit-exact差分/热路径编译期门控保非REPL指令数不变/复用三路评审GC核对)。外置清单(P2):registry lock-box重置#f+root-expand-ctx复位+thread-cell per-place重播种+xrepl.rkt:52/1365两处重跑xrepl实例化。

## P1.1 设计定位:闭包序列化=现有机制有界扩展(2026-09-07,读 fasl.c/fasl.ss)
**关键发现**:C端 fasl_type_closure 读取器(fasl.c:1064-1073)**只支持零自由变量闭包**——S_closure(0,0)零槽+只设code entry(CLOSENTRY=cod+offset,offset须=code_data_disp)。编译器能写它(顶层过程纯code无捕获),但**racket/init 带free-var的模块闭包(捕获模块状态)过不了:free-var向量没序列化**。code读取器 fasl_type_code(fasl.c:1125)已存在。
**⇒ P1.1 真实任务(有界,非从零)**:
- 写入端:fasl.ss wrf(else前,703 hashtable分支附近)加 [(procedure? x) ...] 分支,写 free-var数量+逐个free-var(递归wrf)+code。参照 wrf-pair/wrf-vector 的 wrf-graph 图共享模式(闭包可能有环/共享,须走 wrf-graph)。
- 读取端:扩 fasl.c:1064 fasl_type_closure case,S_closure(code,N)分配N槽+逐个faslin填 CLOSIT槽。现只 S_closure(0,0)。
**最小 spike 起步**:先扩写入端支持**零free-var闭包**(读取端已支持,零C改动验证写路径通)→再扩free-var向量(写count+槽,读端加分配填槽)→R1 bit-exact单闭包往返($closure-code/$closure-ref/arity/name逐字段)。
**风险再确认(R3)**:wrf 加 procedure 分支在**热路径**(所有fasl-write),须编译期常量门控或放 else 前但保非procedure路指令数不变(procedure? 判断成本)——A/B必测非REPL fasl吞吐。
**下会话P1.1第一刀**:fasl.ss wrf + fasl.c closure case,从零free-var起,make base重建(改Chez核心须全重建),bit-exact往返验证。改动面隔离:先只让手写测试闭包走通,不碰.zo写入默认行为(编译器写.zo不该突然产生带free-var closure,须确认默认路径不变)。

## P1.1 关键安全约束:必须加新 fasl 类型,勿改现有(2026-09-07,防.zo破坏)
**发现**:fasl_type_closure(=6,cmacros.ss:505)被 **compile.ss:373(编译器写.zo!)+ strip.ss:612** 使用,写零free-var顶层过程闭包。**扩展其线格式加free-var count会破坏所有.zo读写兼容**。
**⇒ P1.1 正确设计**:**加新 fasl 类型**(如 fasl-type-closure-with-freevars,cmacros.ss 新常量+反序列化端 fasl.c 新 case),现有 fasl_type_closure 空闭包格式**原样不动**→.zo兼容保住。写入端 wrf 的 procedure 分支:0 free-var→仍走(或复用)现有空闭包路,>0 free-var→新类型(count+逐free-var wrf-graph+code)。
**下会话P1.1施工顺序(修正)**:①cmacros.ss 加 fasl-type-closure-freevars 常量(注意 fasl-type 枚举值不冲突)②fasl.c 加新 case(读 count+N槽→S_closure(code,N)+逐faslin填CLOSIT)③fasl.ss wrf 加 procedure 分支(走 wrf-graph 处理共享/环,0fv 可先复用现有或统一新类型)④make base 全重建⑤跑 scratchpad/p11-roundtrip.ss 转绿(现 FAILS=4→目标 P11-ROUNDTRIP-OK)⑥.zo兼容回归(pvector.rktl 等,确认编译器写的.zo仍读得回)。
**R1 红测试台就位**:p11-roundtrip.ss(纯Chez,4样本0/1/2fv+case-lambda,bit-exact逐字段+行为等价,现精确命中 invalid fasl object)。
**方法论价值**:又一次"动手前只读调查"防患——扩现有格式本会破.zo全家,grep一次锁定 compile.ss/strip.ss 两个隐藏写入者。

## P1.1 施工细节:新 fasl 类型枚举值=47(2026-09-07)
fasl-type 枚举现状:...44 uncompressed/45 gzip/46 lz4(后断层)/100 fasl/101 vfasl/127 terminator。**下一个干净空位=47**。P1.1 第一行编辑:cmacros.ss 加 `(define-constant fasl-type-closure-freevars 47)`;fasl.c 读取端新 case 用同值 47。注意 fasl.c 里 fasl 类型 case 常量须与 cmacros 同步(c 端有对应 #define,见 boot/tarm64osx/equates.h 生成——改 cmacros 后 make derived/base 会再生)。

## P1.1 落地:Chez fasl 闭包序列化(2026-09-07,提交 9e2619e657,feat/repl-startup-analysis)
**里程碑**:Chez 内核首次拥有闭包 fasl 能力。新类型 fasl-type-closure-freevars=47:写端 bld-closure/wrf-closure(procedure? 且非 continuation,走 wrf-graph 保共享/环;活 code 不进流,经 externals 通道,匹配"code 走 vfasl 段、实例化态走 fasl"的第四段架构);读端 fasl.c case 47(先造壳 S_closure(0,n) 支持环→faslin code 设 CLOSENTRY→逐 faslin 填 CLOSIT,同 vector case 既有直写模式)。现有 .zo 用的 fasl-type-closure 未动(格式兼容),新分支在全部既有类型测试之后(非闭包路径零成本=R3)。
**验证**:p11-roundtrip.ss 红转绿(4样本 0/1/2fv+case-lambda,bit-exact 逐字段+行为等价);pvector/vector/fasl 三套件全过(.zo 兼容 ✓)。构建含 Chez 重自举。
**方法论坑**:python 大块锚文本 replace 对 fasl.ss 失配(原因未明,可能不可见字符)→逐行 find+插入法稳;补丁脚本中途 assert 抛出时 write 未执行=磁盘无半补丁态(安全)。
**下步(P1 余下)**:①多 external 序问题(shift-externals! 的最终 id 分配序 vs 发现序——单 code 测试无歧义,多 code 场景须核)②免 externals 的闭包内 code 引用形态(第四段场景的登记表设计,联 P4b library-entry 经验)③P2 外置机制(registry lock-box 等)④实例化态整图序列化小样(从单闭包到 module instance)。

## P1.1 三面验收(2026-09-08)
**正确性 ✓**:p11 v1(4样本 bit-exact+行为)+v2 扩展电池(E1 多external序/E2 graph共享/E3 环经box自指/E4 闭包持闭包/E5 百层深链)全绿;pvector/vector/fasl 三套件全过;多 external 序两端源码闭环(shift-externals! 常量偏移保发现序=fasl.c graph 表尾部填充,fasl.ss:230-236+fasl.c:1199-1208)。
**性能 ✓(A/B 双向重建)**:write 基线 35.7-37.6 vs 改后稳态 33.8-35.7(略快);read 2.72-2.78 vs 2.55-2.65(略快)——零回归实锤;首测 46.5 与中间 37.8-38.9 均为冷首轮/构建间布局噪声(教训:fasl 微基准须稳态多轮,构建间 ±4% 布局漂移)。负载=指数级共享树(bld 分派海量调用,对分支成本极敏感)。
**pb 引导链**:新常量 47 令 pb 种子 equates.h 过期→make base 在 pb 阶段 undeclared 失败;按 P4b 归零纪律 make pb-build(纯源自举)+种子 amend "new build"(不 push)→PBB:0 自洽恢复。**规则追加:cmacros 加常量=必须 pb 种子再生**(比表行新增更严:表行宏新鲜加载可豁免,常量进 equates.h 不可)。
**代码质量**:code-review(v9.3-dev,high)后台评审中。

## P1.1 三面验收收官 + code-review 副产物(2026-09-08)
**P1.1(9e2619e657)三面全过**:正确性(p11 v1+v2+三套件+pb自洽)/性能(双向重建A/B零回归偏快)/**代码质量(high 级 review 对 fasl.ss/fasl.c/cmacros 内核改动零 findings)**。
**review 副产物:pvector 工程 15 条 CONFIRMED 欠账**(审的是分支全 diff,含已并主线的 pvector 工作),与 P1.1 无关but真问题,merge 前该清。严重度分层:
- **S1 硬伤(数据损坏/构建失败)**:①pvector.ss packed word+2^54 cap 假设 61 位 fixnum,32 位 CS(pb32/i3)无 (fixnum-width) 守卫(swisstable/patricia 有!)②prims.ss meta-cond else 漏 $pvector-args/$pvector-finisher 定义,32位x86 boot 失败(rumble 无条件引用)③write 模式 #pvector(elem...) 无 escape,元素形状撞 expanded/raw 形→读回变值/报错(违 scrbl 707-710 承诺)④raw-defs-shape? 拒空 defs→#pvector(Empty ()) 空 pvector 读回成二元素(写端 raw 模式仍产此形,静默损坏)⑤cons-left/right/insert 不查 cap,共享翻倍+cons 溢出 packed word。
- **S2 语义偏差**:⑧pvector-map 单参误匹配变参 clause(cdr 内部错+arity 假报)⑨pvector-member 等价参数序反于 vector-member⑩partition 谓词双跑⑪write Θ(length) 对共享结构挂死(2^51 长度微秒建成写不完)⑫reader-graph #N# 占位符不解析⑬BC fallback 无契约校验⑭builder 续延重入产垃圾第二结果。
- **S3 套件卫生**:⑥place 测试块无 BC/places 守卫⑦BC 分支断言改错⑮vector.rktl 新测试块在 (report-errs) 之后(不计入汇总)。
全清单细节存 code-review 任务输出。修复=独立工作包,范围待用户裁。

## P1 实验门裁决(A):module instance 整图 fasl 往返成立(2026-09-08,subagent a496)
真实模块(sort/path-list/promise/kernstruct)整图往返全通。**炸点仅两类**(foreign裸指针/泛型Chez哈希表)3轮收敛;**正确刀法=段差**(构建时标记既存堆~2万对象,凡既存皆外置命名引用):promise图 5.6万节点(B配置经kw-wrapper闭包fv链泄漏整世界:parameterization/scope缓存/io-thread注册表→place→custodian)→段差后1250节点/24KB;整世界上界1.78MB/4016 externals。往返质量:sort 0/37失配、行为探针6/6含contract错误逐字节同文;nongenerative uid跨fasl归一;残余失配全定性(uninterned symbol新对象/弱副本回收/活体计数漂移=快照语义,无未知项)。
**P2 施工图**:第四段=堆标记段差+code走vfasl+既存对象命名引用+**共享表变更重放**(registry新条目等段4对既存可变表的写须重放/补丁携带——同进程小样身份传递掩盖了它,P2首项)+段内新生uninterned/生成性rtd跨段引用须externals或读端归一(P2次项)。脚本复用:scratchpad p1.head/engine/*.driver.ss。
**方法论**:R2遍历器补stencil-vector边(小hash/intmap都在里面,897 instance只3个带路径之谜=此盲区);Chez format无~.40s;#%kernel在Chez reader须(string->symbol);Racket raise须eval出的with-handlers包。

## pop 残余治愈+算法层清账完毕(2026-09-08,baae13de89+46e6bf6deb,merge a4f5675a42)
pop 残余根因=**互锁环**:suffix=1 兜底整树 slice→slice 产满 node3 脊柱→下次溢出全程分裂+1→再 pop 又 slice(纯 cons 摊还正常恰证 concat 无辜)。修=正规 finger viewL/viewR:node-pop-right/left 沿脊柱弹最右/左叶(rest 用 concat 平衡重组),叶的 2~3 元素重装 edge digit;双端对称接线;slice 兜底只剩无 middle 情形。顺带 merge 互递归化(高差任意向真沉)。战果:四种 pop 交错 1001→12、mixed 68×→1.1、双端队列 12、4000 步五操作模型对拍全等、12 路径审计全≈1。深度断言入套件。
**方法链**:审计器(12 profile depth/log2n)→逐步深度 trace(+1 步定位)→形态假说→现场 dump 证伪两轮假说(merge 并列/互递归都非主因)→锁 slice 满脊柱互锁。教训:循环退化要抓"哪步+1"和"该步输入形态",假说必须现场证伪。
## P2 首项裁决(A):写入面收敛,施工图完整(2026-09-08,subagent a4b0)
racket/init 实例化对既存堆写入面:**强面仅 42 容器/1144 条**(registry 声明+330/实例+45/shifted-requires+347/bulk-binding+330/rumble 结构属性三表+627/绑定 box 等),**值→既存=0**(无复杂重绑)、弱删=0、叶写=0。弱面 5268 条集中四类 intern/cache(各有 replay-or-rebuild 通道)。(c) 红旗全定性"不重放+自然重建"(guardian/will 全绕 links-cache 的 fs-change-evt,丢 cache 即消 OS 句柄;计数器自然自增;lock-box 复位确认)。**补丁表原型全通**:回滚→重放 8/8 等价;fasl 往返 8.38MB/11335 externals,补丁容器身份 1144/1144,失配全是 P1 已定性 uninterned 副本零新类。施工图三专项:①keyword/rmp/prefab intern 式重放②thread-cell per-place 播种③links/module-cache 一律 reset。xrepl 增量主体 eq-hash-code 表(叶值),强增量仅~120。脚本 scratchpad p2.*。

## P3.1 裁决(A):跨进程端到端成立(2026-09-09,subagent a477)——内核路五门全通
进程 A 产段三件(state.fasl 8.04MB/8568 externals 定点2轮收敛、manifest 428KB、补丁1000 ops)→**全新进程 B** 反查拼装(loc 1079/1079=100%、rtd uid 100%、rmp/kw 100%、code 走查 85.9%)→fasl-read 10ms→补丁重放 984 应用/0 失败→**五项验收全过**:算术/init绑定/sort/require racket/list+冷载 file-sha1(registry 重放终极检验)/契约错误。溯源证实答题的是 A 段副本。B 全链 0.65s。
**三方对照定性**:深水探针(match/contract/class)失败=spike 简化(B 双实例化混合态,弱缓存指 B 旧世界)产物,B 不重放 12/12 过、A 自身 11/11 过——真 P3 中 B 不自实例化,混合态按构造不存在;代价=真 P3 失去暖态兜底,(c) 类重建钩子须直接验证(留窗口2)。
**关键新知**:①**rtd 原生进 fasl 图触发 Chez 'not in table!?' 内部崩→rtd 必须外置 nongenerative-uid 语义命名**——顺带落地 P2 的 kw/rmp/prefab intern 三专项(全部外置+语义名)②**HAMT(immutable hasheq 的 stencil-vector 节点)结构索引跨进程作废**(布局依赖地址哈希)——穿 HAMT 的引用必须走查表语义边;codeloc 901 条仅 2 命中即此故③eqv 表 fasl 不支持→kv 并图+B 新建回填(3 表全过)。
**留真 P3 两窗口(均非阻断)**:①code 供给归 vfasl code 段(届时 code 命名问题整体消失)②(c) 类重建完备性直验+custodian/thread 子图。
**内核路总结:P0(三审计)→P1.1(闭包fasl)→P1(整图往返)→P2(写入面42容器/1144)→P3.1(跨进程)全链裁决(A)**。剩真 P3=构建链集成工程(build.zuo四段/embed-boot/boot.c/main.sps 条件装载,a957 蓝图机械步骤)+两窗口。脚本 scratchpad/p3/。

## P3.2 裁决(B):真进程全链打通,收益前提须重估(2026-09-09,subagent ae40)
**成立**:真racket进程宿主机制(racket -q -n -t #%kernel模块+primitive-lookup 'eval+copy-environment干净环境——脏interaction-env与wpo空壳库两障碍已解,p1/p2/p3引擎零修改装入);A/B真进程段机制迁移成功(loc 1084=100%、重放1848/0失败、验收8/8、(c)钩子h1-h5全生效);**段本质装载仅55ms**(manifest+loc 8/解析27/读3/解码11/钩子1/重放5)。
**不成立**:①12探针5/12与P3.1同谱——根因=code供给简化的**双实例化身份分裂**(instance普查实锤:arrow-val-first三份全量实例/class-internal双份+壳;init期新建rtd未外置随fasl复制出新身份撞prefab intern;mpi双键)——钩子不能合并两套身份,唯一根治=vfasl code段供码②**收益天花板**:racket/init净成本仅77.5ms,段模拟净收益~22ms(28%)——单为此做P3.3证据不足。
**付费教训级发现**:段对boot态指纹极敏感(runner改一行→B劣化2/8且loc"成功"解析到错对象无从自检)→**P3.3必须段+boot态指纹绑定校验**。
**P3.3若启动的施工序**:①vfasl code段(根治双系+删495ms模拟开销)②身份外置扩到init期rtd/mpi/instance③指纹校验④**收益前提重估:覆盖面须扩到racket/init+xrepl+expeditor(真tty 256ms档)或与hot-reload/'consistent合流**,否则77.5ms天花板不值全量投入。
**战略决策点(待用户)**:A=P3.3全量但目标定完整交互档(256ms→~80-100ms级,配得上机制投入)/B=收口内核路(机制五门+P3.2全证实记档,22ms实用不值)/C=与hot-reload工程合流(闭包序列化能力另一用途)。

## P3.3a 裁决(A):code 段原型攻坚成功(2026-09-09,subagent a842,重大里程碑)
**12/12 深水探针+8/8 验收全过**(P3.2 的 5/12→12/12);双实例化根除有直接证据(attr2/3 单谱系 eq?=#t、census 零双 instance)。覆盖 999‰(10516/10524)。核心链 146ms(vs P3.2 232/1274),段体积 8.21→4.09MB(-50%)。
**攻坚技术清单(全部入 p3.3 脚本)**:①**清单法=A 端 current-load 拦截**(326 次装载全 .zo,事件序即清单序,A/B 同读取函数)②**机制修正:.zo fasl 不直接产活 code**——linklet code 字段是内层 fasl bytevector,须 eval-linklet('faslable-strict→'callable)产活,但无需实例化;A 拦截时先 eval-linklet 再声明保 eq 一致③**code-focused 走查纪律**:reloc 只降 $code 直引+闭包型 reloc 项的 $ccode(零自由变量模块级函数藏在 reloc 静态常量闭包!);record 只降 linklet 第0字段与 wrapped-code;宽松走查会连通注册表致 seq 错位→错接线→GC 崩④五路命名:zo(事件,seq)8117/loc 1105/bdw 37/cpb 创建探针 6/zoloc 1⑤**prefab rtd 按键外置**(prefab-key->struct-type 内在化,修 match/#s 分裂)⑥**(h6) rtd uid plist 恢复**(392 rtd/1729 putprop;须含 record 自身 rtd($rtd x 不在字段);plist 值闭包含不可解析 code 的选择性丢弃 90 条)⑦哑 code 按 free-count 构造(GC 纪律)。
**8 个缺口全定性**=init 期新建、闭包在 boot 静态代 code 上的实例(regexp matcher×5/lazy syntax promise/构造器族)——12 探针不触;此即 P3.3b ②的精确范围(boot 静态 code 命名供给,s_get_reloc 对静态代不可用,须创建事件重放或另设计)。
**稳定性附注(P3.3b 加固项)**:A 产段 run 间方差(3 组中 1 组 class 族 invalid memory reference,B 对固定产物 5/5 确定)——GC/弱引用时机影响段内容;候选=A 端 mark/patch 前显式 collect 纪律。
**P3.3b 清单**:①覆盖扩 xrepl+expeditor(真 256ms 档)②boot 静态 code 供给(8 缺口)③段+boot 指纹校验④A 方差加固⑤zo 表按需化((事件,linklet键,seq)已预留,B 94ms 可再压)。

## P3.3b 进行中(2026-09-09,主线亲做——subagent 通道四连卡死后切换)
**已完成**:①runner 扩面(init 后 dynamic-require xrepl+toplevel-prefix,拦截器挂着收 zo 事件:326→342)+收割前双 GC②**ftype 炸点三步排查定案**:名字猜测 miss→内容扫描 miss→语义厘清("containing"=ftype 指针指向的 C 内存内容,载体字段是裸地址)→**标准谓词 (ftype-pointer? v) 一击命中**,类规则入 p1.engine(ftype-carrier);A 侧扩面产段绿(4.2s,段 5.14MB/manifest 11487 项)。诊断法沉淀:quick BFS 无 guard 踩雷,engine 成熟遍历才可靠;racket 文件嵌大段 quoted chez 易括号失衡,独立 .ss+p32-load-into 稳。
**当前卡点(下轮入口)**:B 端数字全健康(loc 1293/1293、解析 995‰、重放 2052/0 失败、sort 已换段副本)但**求值全谱崩 #%app unbound(展开层断)**。诊断收敛:扩面引入 57 个 MISS 外置(foreign/other 26+ftype 7+zomiss 24,P3.3a 仅 8)——xrepl 拉进的 ffi/ftype/foreign 对象外置后 B 拿哑对象,而它们在展开链(root-expand-ctx/顶层绑定表)图里。**正确刀法=A 端收割/图构建时剪断这些持有边**(P2 (c) 类+plist 选择性丢弃同款),非外置。**下轮=xrepl 增量外置面审计**:对 57 个 MISS 对象做 holder 取证(engine 遍历带 parent),逐条定剪/外置/重建,重点 root-expand-ctx 与 ns 绑定表的图为何可达这些对象。
**subagent 通道注记**:P3.3b 期间 4 个 subagent 连续 600s watchdog 卡死(均在"读文件研究"步),主线小步(tmux 后台+轮询,每步<30s)推进有效。

## P3.3b 续(2026-09-09 下半场,主线小步 11 轮 A/B)
**两刀正向优化落地(xrepl 安装副本,与 terminal-port?/tstring 同族,待 vendor)**:①make-readline-reader 的两个 dynamic-require 惰性到首调②RL-stdin 分支的 (dynamic-require 'readline/rep-start #f) 整段惰性(它是"stdin=tty 但 expeditor 未开"场景的第二 eager 点——tmux-pty-stdin 环境实锤)。效果:**A 段 iter1 零炸点直通**(5.03MB/10986 externals),ftype 7+foreign 26 全消,MISS 仅剩 zomiss 9(与 P3.3a 同谱系无辜)。
**取证方法沉淀**:①ftype 真身=readline ffi(变量名指纹法:instance 表 symbol 键集合=模块身份指纹——libreadline/add-history/old-libedit 一目了然)②"containing"语义=ftype 指针指向的 C 内存内容,载体字段是裸地址(名字猜测/内容扫描两轮 miss 的根源)③(ftype-pointer? v) 标准谓词整类外置=engine 永久规则④行为探针(管道下 declared?)与堆指纹(diag)结合定位装载源环境依赖(tmux pty stdin)。
**当前卡点(下轮二分入口)**:B 端仍全谱 #%app/let-values unbound,但错误全在**宏模板内**=语法 scope/binding 层——xrepl 挂载对 expander 编译期状态(scope/绑定表,可能在弱面/stencil 深处)的写入超出 P2 racket/init 审计面。zomiss/ftype 已排除。**二分实验(各~5s)**:(1) 当前代码 A 不挂 xrepl→B 应 12/12(复现 P3.3a,确认扩面增量是唯一变量) (2) A 只 dynamic-require 'xrepl 不打 toplevel-prefix→切分挂载两步谁写入编译期状态。然后对肇事步做 p2 式写入面 diff(含弱面)找 scope/binding 容器。

## P3.3b 根因完整定性(2026-09-09 晚,7 轮二分闭环)
**二分链**:BX1 无xrepl=0 FAIL(基线复现)→BX2 require-only 即崩(toplevel-prefix 无辜)→补丁差集 58 条(none vs ro 归一 diff)→BX5 全类skip→(a)活(方向=补丁侧)→BX6 只skip namespace-rec→(a)活但d2崩(全类过宽)→BX7 精确单条skip(representative-scope slot)→**(a) PASS 且错误谱变形**:require/match undefined。
**根因叙事(全链自洽)**:肇事=补丁里唯一一条 `ns.f2→root-expand-context→multi-scope→representative-scope.f2` 槽写(A 系顶层绑定表整体覆盖)。机制:该 rep-scope 是 mark 既存对象(kernel attach 的顶层 scope),A init+xrepl 后其 f2 绑定表含 racket/init 顶层绑定;重放=A 表(stencil hamt)整体覆盖 B——**A 表内 scope 与 B 端 zo 装载新造 syntax literals 的 scope 不归一**(xrepl 面破坏了 init 面恰好成立的 gensym 归一)→宏模板 #%app 查绑定失败。skip 该条→scope 归一恢复((a) 活,kernel 级绑定在 B 自表)但 **racket/init 的顶层新绑定(require/match)只在 A 表**→undefined。**即:这条 op 既不能整体覆盖也不能整体跳过——必须"表合并"**。
**两个候选设计(下轮定夺)**:(D1) **绑定表合并重放**:重放器对该槽特殊处理——遍历 A 表(stencil hamt)条目逐个插入 B 现表(保 B 底座+scope 归一,注入 A 新顶层绑定);需 Chez 端 hamt 遍历+expander 表插入api(内部结构,工程量中)。(D2) **scope 统一策略**:让 B 端 zo 装载的 literals scope 与 A 段 scope 走同一归一通道(深改,风险高)。倾向 D1。
**为何 init 面(P3.3a)12/12**:init 面该槽两档都写但 A/B 表恰同构(双方 zo 面对齐+gensym unique-name 归一足够);xrepl 面 A 多 16 模块的 literals/scope 进表,B 端(不实例化)无对应,gensym 归一不再охват全部。
**顺带修正**:zo events 330(非342)=readline 双惰性化后 xrepl 面正确事件数(降 12=readline 系 .zo 不再装)。

## D1 实现与新状态(2026-09-09 深夜)
**D1 深合并已实现**:runner 加 rkt-merge-syms 桥(#%kernel 风格两层 fold:外层 sym、内层 scope-set→binding,B 底座+A 增量);B driver rep-scope 分支=构造新 table record((#%$record ($rtd b) merged merged a-bulk))写回 scope 可变槽。
**途中撞+修**:$rset! mutate immutable table record(pure space)→sweep_dirty(gc) unexpected space 崩——**复证 data 零拷贝评审红线(pure space 不可原地写)**;修=新建 record 替换,engine 对 expander 系 immutable struct 一律"新建替换"纪律。
**新状态(症状升层)**:GC 不崩、(a) PASS、applied 1978/failed 0;但 require/match/let 报 **"undefined; cannot reference before definition"(变量无值)而非 "unbound identifier"(无绑定)**——与 BX7 skip 态同文,两种可能未判:(i) D1 未真生效(分支/等价性问题)(ii) 合并生效、绑定已入,但绑定指向的顶层变量在 B 侧 instance 无值(变量层断,又一层协议语义)。
**下轮首实验**:B 探针 eval (identifier-binding 'require)/(namespace-variable-value 'require)分别判绑定层/变量层——区分 (i)(ii);若 (ii) 则追顶层变量定义(definitions instance)的补丁/段路径。

## 诊断包首战果(2026-09-09 深夜续):两真相一修正
**调试机制**:runner 加 rkt-probe-layers(binding层=identifier-binding/变量层=namespace-variable-value 双探)+rkt-syms-peek(表count+关键符号存在性);driver merge 现场三表侧写+验收前四符号判层。坑:#%kernel 无 and(又踩,P2 已记)。
**真相1**:死磕的 rep-scope 表**两边皆空**(B0/A0/merged0)——它不是顶层绑定的家;D1 合并空表无效;overwrite/skip 行为差异需重解(空表 record 身份 A/B 系之别引发查找差异?)。
**真相2(修正误读)**:require/match 是 **binding 层缺失**(identifier-binding=#f),非变量层——顶层语义:无绑定→fallback 顶层变量引用→报 undefined(文本误导);+/lambda 健康(kernel attach)。racket/init 的顶层绑定在段 ns 查不到,且不在盯错的那张表——在 ns 另一 scope 表(A 进程可查,段化后断)。
**下轮**:A/B 对照表普查探针——dump ns.f5 scope 组各 scope 的绑定表 count+require 落点;A 答"家在哪"、B 答"哪断了"(表丢 vs scope 键失配),diff 锁死。

## 根因终画像:混合 scope 世界(2026-09-09 深夜,census 对照定案)
**数据**:B census=A census(2903 符号 require/match 全在)=表内容零丢失;+(B attach 写入,B 系键)可查、require(A init 写入,A 系键)不可查——同查询异写入方=**scope 键系属失配**。census 的 BINDING-ERR=遍历强制 lazy syntax promise 踩 zomiss 哑 code(附加噪声+哑 code 暴露面确认)。
**根因**:段 ns 结构两类来源——mark 前既存(root-expand-ctx/顶层 scope 族)被外置→B 解析为 B 系对象;init 后新造随段(A 系)。B eval 经 B 系 root-expand-ctx 引入 B 系 scope 查 A 系键→失配。**外置面粒度错误:scope 家族必须整族同源**。
**修法定型(=施工序身份外置②具体化)**:scope 家族(root-expand-context/multi-scope/representative-scope/scope/ns scope 组)从 loc 外置排除→整族随段 A 系;段内自洽(A 表含 kernel 绑定);改点=A 端命名/外置谓词加 rtd 名族排除,重产段,B 全链。D1 表合并可能随之不再需要(整族 A 系后 rep-scope 表天然 A 系)——保留代码待验后清理。
**调试机制沉淀(本轮建,永久)**:rkt-probe-layers(binding/variable 双层)/rkt-syms-peek(表侧写)/rkt-ns-census(L1 公开 API 普查,一举分"表丢vs键失配")——A/B 对照探针法。

## scope 家族段内化首试倒退(2026-09-09 深夜末,有效排除信息)
六名单(scope/representative/multi/shifted-multi/root-expand-ctx/table)排除外置→(a) 也断(#%app unbound 回归)=**名单不全切开新缝**(expander scope 一族还有 interned-scope 等/或 eval 引入 scope 的入口走了未覆盖对象)。**结论:猜名单枚举不可行,下轮系统法**:①scope.rkt 全 struct 清单一次拿全②B 端"eval 引入 scope 溯源"探针(打 eval 造的语法其 scope 对象是段内 A 系还是 mark B 系,判定入口路径)③再定完整族边界。当前 a driver 的排除名单保留待改。

## 终极根因与修法定型(2026-09-09 收尾)
**探针炸点文本闭合最后拼图**:BINDING-ERR 真身=kw.rkt:1250 #%app unbound——identifier-binding 是 kw 协议函数,探针自身走断链(三态探针实为展开链整体状态镜)。
**终极根因**:断链核心=B 端 zo 装载的宏模板(kw.rkt 等)syntax 带 **B 系 core scope**,而其查询的绑定挂在段/A 系 core scope 上。core scope 是 **interned-scope(key='core 等,scope.rkt:144)**——设计上跨进程身份应经 **key intern 归一**(同 rtd nongenerative-uid/gensym unique-name 两先例),但我们的 fasl 通道对它做裸副本→A 系 interned-scope 副本≠B 系同 key scope→两个 core scope 并存→一切绑定按各自系分家。三种外置策略(全外置=B系覆盖表键A系/半族/全族段内=副本不归一)都无法弥合,因为**归一必须按 key 语义而非按对象搬运**。
**修法定型(窄且同构于既有先例)**:interned-scope 从 scope-family 段内名单**反向移出**,加专用外置规则 'interned-scope(spec=其 key,scope.rkt:144 字段),B 端按 key 经 expander 的 scope intern 机制解析到**自己的同 key scope**——与 prefab-rtd(按 key 内在化)/rtd(nongenerative uid)/kw/rmp 完全同构。非 interned 的 scope 族维持段内(A 系,自洽)。待办:B 端 intern 解析通道(racket 桥:expander 有无公开/半公开 make-interned-scope 或 intern 表访问——查 scope.rkt interned 实现)。
**判据回验**:此方案下 B 系模板(core scope=intern 归一同一)查段表(core 键=同一)应命中;A 系新 scope(非 interned)键的绑定段内自洽。预期 (a)+require/match 同活。
**本日侦查链全记录**:45 FAIL→二分(xrepl require 即污)→补丁差集→skip 矩阵→单 op(rep-scope)→D1 深合并(+immutable record GC 红线复证)→空表真相→判层探针(census 2903 零丢失)→混合 scope 世界→家族段内化两试(interned-scope 遗漏发现)→探针炸点文本→**interned-scope key 归一缺失**。每一步收敛,无回退。

### D8 实验记录(interned-scope 按 key 归一)
实施:p3.naming.ss dw-walk! 登记钩(iscope-tab: key→本堆 interned-scope,B mark walk 顺路建表,纯 Chez 零 racket 桥)+A 侧 add-rule 'iscope(先于 pre-boot-marked,规则序=添加序)+spec=(vector 'iscope key)+B 侧 iscope-lookup 解析,MISS 打 key。
D8 首跑 A 炸:invalid context for definition (define scope-family ...)——该 define 为 D5 编辑引入;时间戳证据(seg4z-* 全 16:15=D6 A 成功产物)证明 D6 的 45/0 是真实结果(九名单段内化不足),非旧段重放。define 已删除、名单内联进 memq。纪律固化:A/B 退出码必须分别打标(echo A:$?/B:$?),防陈段重放假象。

### D8 证伪与 D9 方案(scope 按 (name . id) 身份外置)
**D8 证伪**:B 端 walk 直方图(新增调试件:dw-walk! 内 rtd 名含 "scope" 直方图+iscope-tab dump)显示 mark 域 scope 世界仅 18 个对象(scope 4/multi-scope 5/representative 4/shifted 5),**interned-scope 计数为 0**——core scope 不是 interned-scope,expander 的跨进程 scope 一致性走 serialize 协议(deserialize-scope/top-level-common-scope 单例)而非 intern 表。interned-scope key 归一路线前提不成立,废弃。
**D9 方案**:scope 身份=eq,id 由 boot 期确定性计数器分配;A/B byte-identical 至 mark 点⇒同角色单例两侧同 id。预存 scope 本体五类(scope/interned-scope/representative-scope/multi-scope 按 id;shifted-multi-scope 无自有 id,按 (phase . 属主 multi-scope id),因其在 multi-scope 的 shifted 字段按 (phase,ms) intern)以 (name . key) 语义名外置,B 端 walk 登记表 equal-hash 解析——覆盖不依赖 loc-path 可达性。init 新造 scope 段内旅行;非本体族(propagation/root-expand-context/table-with-bulk-bindings/shifted-to-label-phase)不进 scope set、身份不敏感,维持段内。
**D8 census-0 之谜未解**(D8r B census 0 vs D6 2903;A manifest 0 条 iscope 时段应与 D6 等价却行为迥异)——若 D9 全绿则不再追;若 D9 异常再回头。

## 2026-09-09 侦查日终局(D8-D26,约 20 轮实验)

### 已验证的根因链与修复
1. **interned-scope 路线证伪**:B 堆 walk 直方图证明 mark 域 scope 世界仅 18 对象、interned-scope 计数 0——core scope 不是 interned-scope;expander 跨进程 scope 一致性走 serialize 协议非 intern 表。
2. **(name.id) 语义外置已落地且工作正常**:预存 scope 本体按 (rtd名 . boot期确定id) 外置(shifted-multi-scope 按 (phase . 属主msid));A 段图里出现的预存 scope 恰 3 个(scope.0/rep.11/2/multi.5=顶层 ns 直挂单例),3/3 外置解析到 B 版;规则审计 18/18 -> iscope、ext 审计证明其余 15 个根本不在 A 段图(escape-path BFS 40 万节点 0 命中)——**无泄漏,早前 SEG-LEAK 15 条全为假阳性**(B census walk 穿过 external 解析边界渗透进 B 原生世界,撞见的是 B 对象本身)。
3. **真病=负 id scope 双份**:zo 反序列化造的 deserialize scope(负 id),A init 造一批(段内)、B 端桥调用又造同 id 一批(native),lineage 分类每对 dup=(native seg)。绑定表键与查询 syntax 各持一份→"undefined"。dup 量随段抽签(40→606→630)。
4. **层探针自身污染验收**:P33_LPROBES=0 关掉 ns-census/identifier-binding 探针后 pass 0→2((a)(b) 过:core 展开链通,#%app/#%datum/map 工作),挂的 8 项全是 A init 期写的绑定(sort/require/for 等)。45 FAIL 时代的数字含探针连带,真实验收面=8 项。
5. **syntax-debug-info 对质**(官方 API,避展开路径):require 绑定在表、context 打印与查询完全一致、match? #f=同 id 异对象实锤;lambda 的 core 版 match #t/kw 版 #f=boot 期绑定通、init 期绑定失配的分界线。

### 基础工程问题(下一阶段优先序)
1. **A 段不可再生(红线未达)**:同代码连产两段 bit 级不同(第 19 字节分叉,大小差 2.4KB)。B 端对固定段完全确定(三连跑一致)。⇒ pass=2/0 的历史漂移=A 产段抽签,非代码因。候选源:eq-hashtable 遍历序(地址/ASLR 相关)→patch 条目序、weak/ephemeron 的 GC 时点敏感、init 期时间戳。**先解决可再生,再谈 dup 归一**——否则一切验收数字不可比。
2. **负 id scope 双份归一**:B 端桥(嫌疑=ns-census 的 mapped-symbols 强制 lazy syntax)现场 deserialize 出 B 版负 id scope。方向:(a) 找到并消除 B 端 deserialize 触发点(桥全部惰性/后移);(b) 或 attach 后对 (name.id) 负 id 对做成对合并(需定谁为准+引用改写,重且险)。先 (a)。

### 调试机制资产(永久装备)
- 探针异常文本曝光(exn-message 替代吞异常)、syntax-debug-info 对质探针、scope-census(对象携带三元组)、dup 检测+lineage 分类(seg/native)、rule-audit/ext-audit/escape-path BFS(A 端规则链三级审计)、iscope-tab (name.id) 登记表、P33_LPROBES/P33_SKIP_H2 环境开关。
### 探针纪律红线(本日血泪)
- **attach 窗口(fasl-read→replay→验收)内禁全堆/段图 walk**——分配改变 GC 时点,扰动 weak 语义(实测 pass 2→0)。诊断 walk 挪验收后。
- **scope 族对象禁整体 display**(循环结构,实测 30GB log 撑爆磁盘;只打标量字段)。
- **编辑与运行必须 && 串联**(编辑 assert 失败后 tmux 照跑旧文件,今日三次假实验)。
- **A/B 退出码分别打标**;A 失败=B 重放陈段(D5/D6 的"invalid context"假阴性教训:define 不能出现在 body 表达式后)。
- 多步 python 编辑要么单步单写盘要么全 assert 后一次写盘+失败中止。

## 2026-09-10 A 段可再生攻坚(D27-D30)
**工具**:p3-mandiff.rkt/.chez.ss(清单结构对比器:顶层槽/per-tag 计数/首异索引/multiset 差集+样本)——一次运行即把"字节不同"翻译成"哪类条目怎么不同",永久装备。
**三层剥离**:
1. **hv 边裸序(已修)**:n3-kids 哈希分支按 c-htkeys 地址序枚举+n3-scan! 先到先得父指针⇒loc 路径抽签(83 条在 r:y:#%boot 与 r:p:<scratchpad路径> 两路线间翻转)。修复=hv 边按 key 稳定串排序。差异 83/84→31/28。
2. **无稳定串键并列组(已修)**:线程做哈希键打印全是 #<thread>,排序并列组内仍地址序(23 条 loc 经 (hv sl ...) 翻路线;loc 总量恒 1234=双路线皆可命名)。修复=沿 dw-kids 先例,并列组整体丢弃,逼确定路线。
3. **class/contract 弱缓存抽签(残余,语义等价)**:段图可达 code 数在 8472-8479 间抖,摇摆集稳定复现=class-c.rkt:1100/1422/1428、class-struct.rkt:100-102、generate(204:83)七个;flip-trace 探针(P33_TRACE_ZO env,zo-a-tab 反查+段图 BFS)证明 PRESENT 者主图无路径→经 h6 rtd-plist 收编进段;plist-dropped(14/18/32)与 zo-named 反相关闭合证据链。**命名表全确定**(mark 22922/n3 21857/zo 表 40289/patch 1999 跨运行恒定);摇摆者全有 zo 名,B 两变体均可解析⇒字节不定但语义确定。彻底根除需 contract 弱缓存驻留确定化,记为产品化阶段事项。
**判定**:可再生达成"语义级"(全部计数与命名协议确定,残余=弱缓存 ±7 code 的字节差);bit-exact 未达,不阻塞主线侦查。

## 2026-09-10 下半场:三层剥洋葱(D44-D58)
1. **第一因修复=A 预热**:A 的 control probes 原在 fasl write 之后跑——段带走全未 force 的 deserialized-syntax box(#f)。runner A 角色 init 后、(current-load orig) 前插入完整验收工作负载 20 项预热(20/20 过)。效果:dup scope 键 557-641→0(负 id 双份世界几乎清空);(a)(b) 核心链稳定通过(2/6,原幸运抽签态变确定态)。
2. **负 id dup 假说终结**:dup=0 时失败依旧;且证明 id 碰撞跨模块本就无害(eq 匹配)。dup census 从此降级为参考指标。
3. **D1 深合并分支移除**:patch op1379(11/2.f2 slot 写)被 D1 分支拦截(按 Chez 表假设合并 racket 不可变哈希=无效);改普通覆盖后 A 的 twbb 表成功落到 B-trio-11/2。
4. **结构层验证全绿**:TL0-TL3 探针(trio 表 peek/REC 导航/ms-5 stencil 扫描/bulk 链)证明:B 顶层 scope 链全 trio 归一、twbb.bulk-bindings 6 条、bba.scopes 成员 trio-eq=y——expander 绑定结构完全一致。
5. **真病灶=linklet 实例变量层**:(#%require racket/base) 报 "$primitive: undefined in module: top-level";sort/require 等 1404 个缺失(census 2903→1499)全是顶层 instance 变量未置——"cannot reference before definition"是变量层报错,非绑定层(sdi match?#f 是红鲱鱼或次要)。待查:顶层 definitions instance 变量表在段/patch 的旅行路径(aux eqvht 只 84 kv;patch namespace-rec 971 条覆盖何容器)。
**调试件新增**:P33_SDI(exn:fail:syntax-exprs 的 syntax-debug-info)、P33_TL(TL0-TL3 顶层 scope/表/ms/bulk 导航探针)、P33_REBIND(#%require 重挂实验)、P33_DUPTRACE(dup holder 链+世系+eq 分叉深度)、A 预热(runner 内)。
**新教训**:try 的 fallback 是值不是 thunk(急 eval 污染输出);'#%kernel 无 foldl;深嵌套区改动用整块重写不用手术补丁。

## 🎯 2026-09-10 P3.3b 验收全绿(D59-D61)
**ACCEPTANCE 8/8 PASS + VERDICT (A)**;扩展诊断 10/12。B 进程(racket -q -n,从未 racket/init)从第四段完整恢复交互层:算术/map/sort/require(热+冷 file/sha1)/sha1/contract 错误路径全通。

### 终极根因三部曲(全链闭合)
1. **A 预热**(write 前跑全工作负载):惰性 syntax 反序列化全在 A 完成,杜绝 B 端铸 scope。
2. **D1 分支移除**:patch op1379(11/2.f2)普通覆盖,A 顶层绑定表落进 B trio-11/2。
3. **h7 eq-hash-code 登记同步(本日最深发现)**:CS 的 eq-hash-code=rumble `codes` 弱表按首问序分配的**进程本地序号**(counter 起 12345);racket hasheq/hasheqv HAMT 按此序号组织;fasl 迁移后 B 端序号不同→**枚举可见(结构遍历)、hash 走位全盲(lookup/subset)**——一次解释 census 2903↔1499、sdi 列出绑定却 match#f、resolve 失败落顶层变量回退的全部矛盾。修复:codes 表经 collect-request-handler 闭包 BFS 定位(库内变量不可直达);A mark 快照→write 时 delta(6223 对,对象走既有外置/in-graph 通道,root 加槽 5)→B install-if-absent(5390 装入,0 冲突,833 非堆立即数跳过)。counter 不同步(hash 允许碰撞,仅退化)。
### 残余 2 失败族(下阶段)
- super-new "not in a class"(class keyword 识别,疑 free-identifier 集合或 syntax-parameter 层)
- provide/contract-*-transformer "illegal use of syntax"(phase-1 值已找到但不被识别为 transformer;疑 h6 rtdprops-dropped=18 掉了其 prop:procedure/prop:set!-transformer)
### 意义
段差协议的三大隐性世界(scope 世系/绑定表身份/eq-hash 登记序)全部显式化并有了同步机制;h7 属**普适级**发现——任何跨进程 fasl racket hasheq 的场景都需要它。

## 🏁 2026-09-10 P3.3b 判词(D64-D70)
**VERDICT (A):核心 8 + xrepl 层 x1-x3 = 11/11 全绿**(x1 current-prompt-read 活、x2 toplevel-prefix 可达返回串、x3 interaction-info 参数可达[unset=本段未公告,合法])。扩展诊断 10/12。

### 计时(P33_PROBES=0,3 连跑 973-1058ms 总;prog 相位分解)
- racket -n boot+实验 harness 装载:~138ms(含 75ms 实验 .ss 装载,产品无)
- **段恢复净成本 ~227ms**,构成:zo 表重放 164ms(实验期命名装置)+manifest/loc 解析~14+state.fasl 读 ~9ms(9.2MB!)+hooks/replay~35
- **产品形态外推:boot 37 + 原生段读 ~10 + hooks/replay ~35 ≈ 80-100ms**(zo 重放归零:产品用已合入内核的 closure-fasl 直带 code)。vs 现状 real-tty 256ms,达计划目标区间。
- 探针模式的 +730ms 尾巴=诊断 census(reloc 穿透加重),非协议成本。

### 残余(挂产品化)
- 2 失败族(class keyword/provide-contract transformer)=rtdprops drop 84 条,根因=boot 静态代 reloc 表被 discard(实测 eval reloc len=0),bdw 无法命名 add-mpi-shifts66 类库内 code;**解=boot.c 调 Sretain_static_relocation()(ChezScheme c/scheme.c:1047,racket CS main 未接线)**——本就是产品化 boot 链条项。
- 段 9.2MB(预热带入全量实例化)、zomiss 10、按需裁剪=产品化项。

### 本轮新增机制
- dw-extra-roots(kernel 原语闭包对,Chez 侧按名排序种入)+dw-walk-rtd-plists!(mark 域 rtd plist 值增量走图,+578 节点,bdw 38→42,drop 106→84)
- dw-kids code 分支 reloc 穿透((cs)s_get_reloc foreign-procedure;对 init 后装载代码有效,boot 静态代无 reloc)
- x1-x3 探针入 B 验收(P33_XREPL=full 段)
### 教训增补
- '#%kernel 无 let(runner 里再犯);Chez let 体内 define 不得被表达式打断(两犯);racket 侧排序难写→(name . val) 对丢给 Chez c-sort。

## 2026-09-10 retain-reloc 战役(D71-D79):前瞻实验+绿基线裁决
**目标**:消灭残余 2 失败族(rtdprops drop 84)。
**已落地的主线 C 改动(env 门控,默认零行为差)**:
1. src/cs/c/boot.c: racket_boot 里 Sscheme_init 后接线 Sretain_static_relocation()(RACKET_RETAIN_STATIC_RELOC=1 时);
2. src/ChezScheme/c/prim5.c: s_get_reloc 对 static-generation code 的无条件拒绝松绑为"仅未 retain 时拒"(retain 下 reloc 表有效可走)。
双修后 boot 静态代常量池可读(car reloc 2/eval 4;dw-walk 41224 节点、codes 7996、**rtdprops drop 0、zomiss 0**——库域命名全覆盖)。
**但全宽判据引爆新灾**:4500 条 prop 值上车,其值闭包的自由变量库 cell 不在 p2/mark 域→in-graph 死副本→B 执行 invalid memory。h6 范围二分排除装载环节(empty-range 仍崩=崩因在段图接线);白名单救援(3 transformer rtd)=打地鼠(date 修好、match/contract 新坏)。
**dwseq 前瞻**(库域通用身份=dw-walk 序号,A/B 已证同序):规则+解析已实装,但 walk 域(41k)仍不含 POST-mark rtd 的 prop 值自由变量→仅命中 31,不解题;完整解需"库域全枚举身份"(walk 域扩到全 static 段或 static 段内偏移名)——工程量大。
**裁决:回退绿基线**(不设 RACKET_RETAIN env,一切默认关):11/11+VERDICT(A)+扩展 10/12+drop 84 复核无损。残余 2 族(class keyword/provide-contract transformer)定性=**库域身份工程**的下游,挂产品化 backlog,优先级让位段裁剪。
**教训第 4 次强化**:python 编辑 assert 失败后 tmux 命令仍发出(顶层语句不受 && 保护)——编辑块与运行块必须物理分离或全链 &&。

## 2026-09-10 晚:正向解战役 II(D80-D87)——三修复落地,残余收敛到 1 族
1. **rtd uid 通道扩宽**(fasl 读崩根因):库域 rtd(29 个,rtd-name=$base-rtd)漏出老 'rtd 规则(mark-ht 条件)坠入 dwseq,rtd-as-dwseq-external 破坏 fasl 图→读期 invalid memory。修复='rtd 规则去 mark 条件(凡 nongenerative uid 皆按 uid 解析);dwseq 排除 rtd/ht。读崩根除(rtd ok 72)。
2. **staddr 通道落地**(static 域通用身份):实测前提成立(20 对象锚相对 fxaddress 偏移跨进程逐一相同,跨 boot 文件亦稳,ASLR 仅整体平移);还原公式 ptr=((anchor+delta)<<3)|tag,tag 由 A 端 0..7 roundtrip 自检;$generation static=7 判定;A spec=(delta . tag),B O(1) $address->object 还原。原语获取教训:p32 env 无 #%$fxaddress/#3% 读法被 racket reader 拒,用 ($primitive $fxaddress) 显式形式。实际命中仅 2(audit 的 NEITHER 12.7 万大头=init 新对象,合法 in-graph;真 static 且 mark 外者稀少)。
3. **reloc 闸门**(晚期 invalid memory 统一根因):retain 下 GC 不更新 static reloc 表(gc.c 无消费点),attach 后 census 经 dw-kids reloc 穿透读悬垂条目。修复=dw-reloc-ok 全局闸,mark 相(dw-walk/cpb)后关闭。D72-D85 全部 B 崩一次解释一次根除。
**战果**:drop=0(全量 prop 值上车且执行安全)+核心 11/11 VERDICT(A)+扩展 11/12(date->string/racket-format 两族痊愈)。
**唯一残余=class 族**,新线索(SDI2):底层 (error #<syntax raise-syntax-error...>)——class-internal.rkt:1432 错误模板 syntax 被当 error message=**惰性 syntax-literal 槽位错位**(B 取 pos_i 得 pos_j;A 同 probe 过)。下一步:比对 A/B class-internal instance 的 syntax-literals 向量逐槽内容,定位错位源(疑与多 phase/多 body linklet 的槽对位或 patch 重放相关)。

### class 族侦查小结(D87-D90,待续)
- CLS 探针(p33-cls-dump,naming.ss 永久装备):registry→按 rmp 路径名找模块→枚举字段+闭包 fv 里的 instance→dump 变量表与 syntax 向量逐槽指纹。
- 判定:A/B class-internal 结构**逐槽同构**(两套 data instance:fv4 空+void deserializer/fv5 998 槽已填;槽 5/7/9 可打印其余循环)——data 层无错位。
- SDI2 揭示的 (error #<syntax raise-syntax-error...>) 形态与验收期 "super-new not in a class" 形态**并存**——前者=transformer 本体把源码 syntax 当值(correlated-linklet 惰性编译/解释器层嫌疑,wc-force 机制关联),后者=关键字判定走 else。**下一战役入口**:对 super-new transformer 闭包做身份解剖(其 code 是 wrapped-code force 产物?B 端 force 路径与 A 差异),及 SDI2/验收两时点的形态差定位。
- 探针纪律第 5 强化:engine try 的 fallback 按值急求值——fallback 里放 (o ...) 会先打印;只放纯值。

## 2026-09-10 深夜:正向解战役 III 收敛(D91-D96)
- **'rtd 扩宽过度定罪与回收**:init 新 rtd(B 无 uid 注册)被外置→fasl rtd 位空洞→抽签崩(d91-d94 5/5 与基线 1/3)。修复=约束 (or mark-ht static-gen)。
- **LIBID 闸门定型**:staddr/dwseq 通道 gated P33_LIBID=1(默认关)。**绿基线 4/4 复稳(11/11+10/12)**;配方线(RETAIN+LIBID)实证可达 **11/11+11/12**(d95 retain pair1)但抽签 ~1/3,源=通道开启后的某非确定残余(externals 布局敏感,待钉)。
- class 族:CLS 探针证 A/B data 层逐槽同构;super-new transformer 不在 declaration 字段(下一入口 ns.f16 phase 实例表);SDI2 的 (error #<stx>) correlated/解释器层线索在案。
- 探针回滚实验证明 d91+ 崩非探针所致。
**当前配置矩阵**:默认=绿基线稳定;RETAIN+LIBID=最高战果配方(带抽签)。

## 🎯 2026-09-10 夜:配方线抽签根除(D97-D106)——6/6 全绿
**walk 指纹工程**(dw-dump-fingerprint!/父链追踪,永久装备)三步定位:
1. 三对崩绿混合样本全部在 **seq 10248 分歧**;
2. 父链修正后锁定分歧真源=**同一 pair 两侧 car 不同 prim 闭包**,父链上溯至 **rec:eq-mutable-hash 的 vec32 桶+pair 链**;
3. 根因=**racket 可变 hash 的内部桶链按插入序(进程本地)被 dw-kids 记录字段遍历**——kp 名单两侧逐行同(1410 项)排除种入层,分歧纯在桶链。
**修复=dw-kids mutable-hash 特判**:eq-mutable-hash/mutable-hash/weak-mutable-hash 只 descend Chez hashtable 字段(dw-kids 已排序枚举),跳过桶向量。修复后 **walk 指纹 4/4 SAME**(A/B 命名跨进程稳定性完全建立)。
**次生回归与反证**:census gate(LIBID 下跳过 pre-eval census)引入确定性 map 死循环——恢复 census 即愈(**census walk=配方线必要预热**,行为契约固化;机制=走图 force 副作用,d46 SDI 先例同族)。forensics 诊断 try 化(不许杀进程)。
**终态:配方线(RETAIN+LIBID)6/6 全绿 11/11+扩展 11/12**;唯一残余=class 族(syntax-literal/correlated 层,线索在案)。
**教训**:macOS 无 timeout 命令;tmux 长单行命令会因折行/粘连失效——多命令一律脚本文件;C-c 时序须确认目标进程。

## 2026-09-11 凌晨:class 族深钻(D107-D110)——缩到 syntax-parameter mark-key 断裂
**收缩链**:
1. minst hunter v2(ns.f16 phase 表路由,p33-find-minsts/p33-hunt-vars 永久装备):class-internal phase0 minst 定位,super-new 变量名 hunt 零命中(transformer 藏名)。
2. 源码机制定位:super-new=parameter-rename-transformer→super-new-param=**syntax-parameter**(默认 not-in-a-class);class 体内靠 syntax-parameterize 重绑(class-internal.rkt:256-284)。
3. **stxparam 微实验**(裸 define-syntax-parameter+syntax-parameterize):B 上 'default(期待 'inside)——**机制通用坏,class 只是下游**。
4. 实现全解剖(stxparam.rkt/private/stxparam.rkt/stxparamkey.rkt):set=let-local-keys 在 with-continuation-mark(key=**stxparamkey 实例的 current-parameter-environment 闭包对象**,stxparamkey.rkt:10-13)内 local-expand;get=apply-syntax-parameter→continuation-mark-set-first(root tag)。
5. **三方对照定案**:A(真 init 世界)='inside ✓;配方 B='default;基线 B=arity mismatch(更碎)。两 B 的 stxparamkey minsts 均 8(多 phase 正常态,数量无差)。微实验对象全 B 本地⇒断裂在**段 attach 后 phase-1 编译期实例的 mark-key 对象 set/get 不一致**(双实例或 key 变量双世界)。
**下一入口**:B 上抽取 set 侧(let-local-keys transformer 闭包的 fv 链)与 get 侧(syntax-parameter struct prop 里 apply-syntax-parameter 的 fv 链)各自的 current-parameter-environment 闭包,eq 对比;或对 phase-1 instance 世界做 union/v<1> 双份 census。修复方向预判:phase-1 definitions/instances 的段旅行完整性(v<1> 表是否共享同一 stxparamkey 实例)。

## 2026-09-14 深夜:灾后校准战役——experiments/seg4 重建版复绿 6/6
**根因**:§9 抢救从 transcript 只提取了各文件**最早的 Write 全文**,丢失其后全部 Edit 链(涉案 78 条 Edit 中 21 条未落位)。
**修复三组**:
1. 手工定位 3 处硬错:p3.2-boot.chez.ss:15 环境对象裸嵌 eval form 缺 quote(载入即报 invalid syntax #<environment>);p1.engine-suppl.ss 尾部 121-133 行旧 find-leak-paths 残片(散落右括号+load 期裸 for-each,reader 直接失败);p3.3-table.chez.ss 缺 cpb 三件套(cpb-build!/cpb-lookup/cpb-ref,从 subagent transcript 的 Edit 记录逐字恢复,锚点=zo-b-lookup 之后)。
2. 系统法:审计脚本扫主+全部 subagent jsonl 的 Edit tool_use,按时间序对重建文件**链式重放到不动点**:21 条全落位(p1.head.ss 4 条=stencil-vector 家族 $stvec?/$stlen/$stref+obj-category/heapish?/children 分支、p1.engine.ss 7 条、p2.writeset.ss 2 条、p3.2-gen.py 5 条、p3.3-enum.chez.ss 3 条=zo-wc-ann 计数器),0 未解;p3.2-head.chez.ss 按 gen.py head 派生逻辑从修复后 p1.head.ss 重生成。
3. 幸存件(naming/a/b/run)的 12 条缺失记录人工判读:全部为"已被更晚版本收编"(如 rkt-creation-probes 现版 make-inspector 晚于记录版 current-inspector)或"刻意移除的诊断"(neg-id scope 探针,对应 §6 已证伪假说),一律不动。判据=幸存件含 D97+(mutable-hash 特判/dw-dump-fingerprint)与 D107(p33-cls-dump/find-minsts)机制,确为晚期拷贝。
**终态:配方线(RETAIN+LIBID) 6/6 全绿——核心 11/11 VERDICT(A)+扩展 11/12,A/B 退出码全 0**;唯一残余仍=class 族 super-new(§7.1 stxparam mark-key,与灾前一致)。A 驱动 ~9.7s、B ~1.0s。
**教训**:transcript 抢救必须重放完整 Edit 链,不能只取最早 Write;审计判据="new_string 不在现文件即缺失"+链式迭代(old_string 命中即应用)到不动点;"抢救后烟测通过"的记录若与入库文件不一致,以入库文件实测为准。
scratchpad 全量(含全部修复)已同步回 experiments/seg4/(文件内 SP 路径常量指向本 session scratchpad,新会话按 §9 方式改指)。

## 🎯 2026-09-15:stxparam mark-key 战役(D111-D124)——class 族根除,扩展 12/12 首次满分
**探针收缩链**(全部新鲜日志实证,B 端 15 秒级迭代:段产物复用,run-stxb.sh 只跑 B):
1. dissect(minst 变量表通道)零命中→改 find-instances 路由:B 的 4 个 stxparamkey linklet 实例中 3 个**共享同一 cpe 闭包**(cpe#0)。
2. **peek-env 差分**(phase-1 直接 require stxparamkey 读 (current-parameter-environment)):B=((0 default) 0)——syntax-parameterize 展开体内 env 不可见。
3. **probe2 自洽测试**:同一 transformer 内、同一变量的 wcm 写→cpe 调用读,B=0——回路自身断,非双实例错配。
4. 层清白书:probe3(phase0 wcm)✓/probe4(显式 root-tag 读)✓/probe5(phase1 fresh-gensym key+直接 cmsf)✓——wcm/cmsf/tag 机制全层正常,唯"经 cpe 函数的读"失效。
5. probe7/8:穿越 key 写的 mark,B 原生 cmsf(无 tag/带 B root tag)**都读得到**——写没问题,cpe 内部读的 key 是另一个对象。
6. **probe10 reloc 转储**(dw-get-reloc 直读;动态代 code reloc 受 GC 维护,post-GC 安全,不受 retain 静态悬垂限制):cmsf/root-tag accessor 走 gensym 库全局(B 原生)✓;但 reloc 里有 **current-parameter-environment 的 0-fv 闭包字面量**。
7. **probe11 终审**:字面量与 cell 闭包 **eq=NO**;用字面量做 key 写→调 cell 闭包读=**1**。模型完全证实。
**根因(普适级)**:**0-fv 闭包身份分裂**。zo 装载进程上,模块 cell 里的 0-fv 闭包与其 code reloc 自字面量是同一对象;段旅行后 B 上分裂为两个:zo 重放新造字面量(cpe 函数体内 mark key 的编译期引用),段图带来 A 的 cell 闭包(racket 层一切变量引用)。凡以闭包对象本体做 eq key 的机制(stxparam continuation-mark key)必断。A 上同一对象故正常。
**修复='zoclo 通道**(三处,~40 行):
- naming.ss:p33-zoclo-literal(code→reloc 0-fv 自字面量);
- A 规则链末尾:0-fv ∧ 非 mark 域 ∧ code 有 zo 名 ∧ **A 上闭包==A 的字面量**(语义保真判据)→外置 (vector 'zoclo evt seq);
- B resolver:zo-b-lookup→p33-zoclo-literal→规范闭包。命中 3 条全 ok。
**消融**:'#%unsafe/'#%paramz namespace-require 扩根尝试(第一版假说=root tag 单例逃逸)被证无效已撤;最终配方=纯 zoclo 单项。
**战果:配方线 6/6 全对 核心 11/11+扩展 12/12 fail=0(工程史首次无残余)**;微实验 'inside、peek ((1 inside) 0)、probe2=1。
**探针纪律增补**:字面 `#%unsafe` token 会炸 Chez reader(装载驱动即死),运行期 (string->symbol "#%unsafe") 构造;engine try fallback 只放纯值(再犯一次);陈日志假象再现——run 脚本一律先 rm 驱动 log;深嵌套补丁括号漂移两次,机械平衡检查(strip 字符串/注释)入固定流程。
**永久装备新增**(naming.ss):p33-stxkey-dissect/p33-fv-hunt-cpe/p33-hunt-ptags/p33-find-cpe-closure/p33-zoclo-literal/p33-collect-insts/p33-inst-vartab;b 驱动 peek/probe2-11 探针群(P33_STX=1 gated)。

## 2026-09-15:zoclo 三缺口加固(D125-D127)——设计文档 §6 全封
设计文档 repl-startup-zoclo-design.md §6 的三缺口按产品化清单落地,全部只动失败路径,happy path 零改动:
- **D125 缺口 1(必做)**:B 端 zoclo MISS 改致命。resolver MISS 分支记样本(i/evt/seq),census 打印后、dummy 布线/fasl-read 之前 `FATAL + exit 1`(p3.3b.chez.ss:347/370/529)。根除静默 #f 注入(zoclo 不在 dummy-code memq 列表,MISS 原样把 #f 拼进闭包位)。**故障注入实测**:evt+100000 强制 3 MISS→B-exit 1+三条槽位样本+无 VERDICT;恢复后复绿。
- **D126 缺口 3**:A 端往返自校验。p3.3-table.chez.ss 保留 per-event code 向量(zo-a-codevecs:10)+反查 zo-a-ref(:37);spec 生成时 (evt.seq) 经 A 自己的事件表+reloc 自字面量走一遍 B 将走的两步,断言 eq 回 x,失败 FATAL(p3.3a.chez.ss:589-608)。zo 枚举确定性从假设升级为构建期不变量。
- **D127 缺口 2**:staddr/dwseq 互斥断言。新 helper p33-zoclo-target?(naming.ss:1185,zoclo 规则的对象侧本质);manifest 构建的 staddr/dwseq 分支若捕获 zoclo 目标即 FATAL(p3.3a.chez.ss:569/583)。gen(4≠7)+walk 成员性推理升级为受检不变量。快速守卫前置(procedure/clen=0/zo-a-lookup),boot-static 闭包不触 reloc 读,成本可忽略。
- **验证**:B-only 冒烟绿;故障注入致命路径实测炸;3 对整对回归全绿(pair1-3 exit 0,zoclo 3 ok/0 MISS,核心 11/11,扩展 12/12,A 端两断言随 manifest 执行零触发)。
- **陷阱备忘**:`(c-flush lp)` 在 manifest 循环/resolve 循环内不可用——`lp` 被命名 let 遮蔽为循环函数,FATAL 块须放循环外或省略 flush(o 每次自 flush)。
- 剩余:§7.3 第 3 项(命名基座随 code 通道产品化改原生 fasl 名)依赖上游,判据不变。

## 2026-09-15:7.2.1 预热实测反转(D128-D131)——none 预热 -45%,定向 force 证伪,方差定性升级
**实现**(runner P33_PREHEAT=workload|force|both|none + naming.ss p33-syntax-force-plan):
- 定向 force=Chez 侧按索引枚举 ns.f7 registry declarations(**rumble rtd 不带源字段名,首版按名查找全 #f**;改索引+rtd-name 校验:registry f0=declarations、module f12=force-bulk-binding,#:authentic 无父)→排序后把 (名 . force-bulk-binding 闭包) 交 runner,racket 侧 safe-eval 逐个调(纪律:racket raise 不能裸 Chez 帧接)。
- env 读取在 A-only 分支内(mark 前读会造 A/B 分歧分配,段对 boot 指纹敏感)。
- **方法论再验证(付学费)**:runner 改动后 B-only 冒烟必炸(新 runner mark 堆指纹 × 旧 A 产物=地址通道错解),runner 属 byte-identical 纪律件,任何改动只能整对验证。
**测量裁决(配方线,整对)**:
- workload 基线 9.26MB;**真 force 生效(353 模块 ok=353 err=0)但段涨到 9.44MB**——全量 force 反序列化超出工作负载触碰集,7.2.1"定向 force 省 4.2MB"的方向被证伪。
- **none(零预热)5.078MB(-45%),验收全绿**:none6 六对 11/11+12/12 全过+矩阵 3 对+首轮意外等效对,共 10 对验收零 fail。历史"A 预热必要"(§5.1 kw.rkt #%app 分裂)已不复现;机制**未理解**(候选=D1 覆盖+h7+现通道集使 B 端惰性 force 自洽,§5.1 故障早于它们),列为待研问题。none 模式下 zoclo 命中=0(cell 闭包不再入图),扩展 stxparam/class 仍全过。
**方差定性升级(重要)**:B invalid memory 崩溃 3 例/配方线 14 对(~21%):workload 对扩展诊断后、force 对 layer probes、none 对 CHEZ FORENSICS census——**全部在诊断性全量走查段,验收路径从不触雷**。⇒ 不是诊断抖动,是**段中存在解析错位的槽**,验收绿仅因未踩到,census 是意外金丝雀。P3.3b 清单④严重度上调为潜在正确性缺陷。三例现场已存(session scratchpad crash-forensics/)。
**green-none 实验(D131)**:不设 RETAIN/LIBID+none 预热,3 对全净 11/11+**12/12**——zoclo 根除 class 族后,staddr/dwseq/retain 对验收面不再必要(历史 12/12 依赖里的 date/format 修复=rtd-uid 扩宽,非 LIBID 门控,仍在)。
**🎯 D131 裁决(已验证):green-none 15/15 全净(3+12 对连续,全 exit 0、11/11+扩展 12/12、5.078MB 稳定)**。按配方线 ~21% 崩率,15 连净 P≈0.03 ⇒ **方差归因 retain/staddr 线成立(推断,强统计证据;非最终根因定位)**。裁决:**green-none 升为推荐线**(env 全不设+P33_PREHEAT=none):机制简化(卸 staddr/dwseq 通道与 RETAIN C 开关运行时依赖)+方差消失+段 -45% 三收。配方线降级为诊断/研究线(staddr 错位槽根因、"none 为何绿"机制两题留研)。zoclo 通道 none 线下命中=0(休眠),加固护栏原样保留。runner 默认 P33_PREHEAT 仍=workload(保历史脚本对照),推荐线脚本显式传 none(run-greennone*.sh)。C 两钩子(已提交 d2220e7fa0)默认零行为差,保留供诊断线。
**剩余(7.2 续)**:5.078MB→数百 KB~2MB 还差一档,下一杠杆=7.2.2 fasl 图裁枝(rtdprops 全量→按需、zo 清单按需化)+7.2.3 分层;产品化清单见 handoff §7.3。

## 2026-09-15 深夜:7.2.2 测量裁决(D132-D133)——容器按需化证伪,字节不在关键路径
**装备**:A 驱动 P33_SEGPROF=1 段成分剖析(p3.3a.chez.ss,write 收敛后)。第一版 solo 写(单槽独写测尺寸)失效——图强连通,patch 单槽可达 4.98MB≈总量 5.08MB,solo 只测"可达量"。第二版**边际剖析**(root 逐槽剔除重写,总量−剔除后=独占字节;patch 按 tag 组同法)。
**边际结果(green-none 5,078,478B,已验证)**:
- 五槽独占合计 **~417KB**:patch 320K/rtdprops 37K/aux 31K/codes-delta 21K/tags 8K;patch 内 tag 组独占合计 ~282K(namespace-rec 95K/registry-table 93K/custodian 60K)。
- **⇒ ~4.66MB(92%)是多槽共享核心图**(ns/expander 世界:patch ops 引用之,h7 codes-delta 的键即其对象,rtdprops/aux 亦可达)。砍任何容器都省不下;**7.2.2 原设想(rtdprops/zo 清单按需化)对字节证伪**(独占 37K/42K 级)。真裁剪须动核心图=7.2.3 分层领域。
**计时(green-none P33_PROBES=0,prog 相位时间线,已验证)**:B 恢复主链 driver-entry→replay-done ≈193ms=zo 重放 **97ms**(330 事件/40289 codes;实验命名装置,产品归零)+bdw/cpb walk ~26+manifest/loc 7+resolve 3+fasl-read+install ~34(读本体 14ms@5.08MB)+hooks 1+replay 24。窗口内 GC ~71ms(zo 重放分配主导,产品同灭)。**产品外推:boot 37+read/install ~34+replay/hooks ~25 ≈ 96ms,80-100ms 目标在 green-none 线上成立**。
**优先级重排(数据驱动)**:段字节(5.08MB)不在 time-to-prompt 关键路径(读 14ms),只关 RSS 红线与分发体积→7.2.3 图分层**降级缓做**;**下一里程碑=7.3 产品化**,首项=code 通道原生化(内核 closure-fasl 47 已在主线,消 97ms zo 重放=最大实验伪影,同时 zoclo 命名基座随动)。

## 🎯 2026-09-15:内核原生 code fasl 能力落地(D134-D136)——P1.1 的下半场
**能力**:活 code 对象可 fasl-write/fasl-read 往返(此前 wrf 无 code 分支=invalid fasl object,闭包的 code 只能走 externals)。P7.3 code 通道原生化的内核基石。
**实现**(无新 fasl 类型,复用 fasl_type_code=11 既有线格式,读端 fasl.c:1138 本已存在):
- `prim5.c s_fasl_code_info`(+注册):活 code 的 flags/字节长/机器码 bytevector 拷贝/free-count/**逐条 reloc 元组**(type/extended?/code-off 增量/item-off/kind/payload)。沿 s_get_reloc 分配模式(C 侧分配只扩堆不收集,co/t 不动)。static-gen 无 retain 时返回 #f。
- `fasl.ss bld-code/wrf-code` + dispatch 尾位两插入($code? 测试在全部既有类型之后=非 code 路径零成本)。**关键机制事实:读端读完机器码后对每条 reloc 无条件 S_set_code_obj 重打 span→活字节里烤死的地址不必清零,原样拷贝即可**;code_off 为累计增量,与活表同约定。
- **D135 分类通道(get-room 事故)**:活 reloc 里的库入口/C 入口/立即数**不可当对象递归**(boot-static 库 code 无 reloc 表,直接炸)——编译器 fasl 对它们走符号化 fasl_type_library/library_code/entry/immediate 索引;写端逆向分类(kind 0-4),bld 只收 kind-0。逆查:globals.h 的 vfasl 逆查表(c_entries/library_entries/library_entry_codes)是**死声明**(写端已迁 Scheme),自建线性扫 library_entry_vector/c_entry_vector(spike 级;产品化可换哈希)。
**验证(已验证)**:
- p73 电池(experiments/seg4/p73-code-roundtrip.rkt)**10/10**:1-fv/0-fv/互递归/自引用 0-fv/裸 code,字段 bit 级+行为等价。
- **t4 前提实测(重要新知)**:纯自调用 letrec 编译成 code 直引,**不产** reloc 自字面量(reloc 全 code);只有"把自己当值用"(eq? n f——恰是 stxparam mark-key 形态)才产字面量。
- **t4-unified 行为证明**:往返后 (sf2 sf2)='self+读端 reloc 字面量 eq sf2——**code 与闭包同图旅行时 0-fv 身份分裂天然不发生**,原生 code 通道下 zoclo 机制自然消失(判据不变)的直接证据。
- .zo 兼容:fasl/vector/pvector 三套件全过。
**缺口(下轮)**:①R3 量化基准未跑(dispatch 尾位理论零成本,fasl.rktl 过=定性;P1.1 式 A/B 稳态微基准待补)②实验接线:A 写 seg4z-codes.fasl(枚举序)/B 单次 fasl-read 换掉 97ms zo 重放,zo-b-lookup 改表索引③PORTABLE_BYTECODE_SWAPENDIAN 交叉端序不支持(记为限制)。
**纪律再证**:#% 前缀是 Chez reader 语法,racket-read datum 里是普通符号,须 ($primitive $name) 显式形式;scheme-environment 缺部分 $-prims($code-name 等),$primitive 全适用。

## 2026-09-15/16:codes.fasl 接线战役(D137-D144)——zo 重放替换全链打通 11/11+11/12
**接线形态**:A 端 `zo-a-write-codes!`(p3.3-table)把 demand 集(manifest 的 zo/zoclo 名,8415/40289,未引槽 #f)经 `fasl-write 第三参外置谓词`写成 seg4z-codes.fasl(32.4MB,~9s)+codes.manifest(外置命名);B 端 `zo-b-build-from-codes!` 先解 manifest 建 extvec(5208 条全解析,未解析槽=FATAL 防 #f 注入 reloc)再单次 `fasl-read 'load extvec` 填 zo-b-vecs——(evt.seq) 索引协议不动,P33_CODEFASL=1 门控,回退 zo 重放保留。
**外置命名全谱(逐雷实测建立,每条都有崩溃现场)**:
- static code(gen=7):bdw 名(dw-codetab);walk 外的 107 个→staddr 兜底。⚠ staddr-static? 的 heapish? 守卫不含 code(40289 全误判 dynamic 的教训),gen 判定直接问 $generation。
- **FFI 目标地址(普适级发现)**:eval-linklet 物化把 foreign 调用目标 relink 成当进程裸地址(tag 4=非法对象 tag=4 字节对齐 C 地址;$generation 返回 #f 而非炸);A 传 B 必错(首轮 staddr 命名→B GC "copy: illegal type"/OOM,ASLR 布局不同构)。正解=`foreign-address-name` 反查符号名→manifest 'fentry→B `foreign-entry` 重解析(180 条全命中)。**产品化 code 通道铁律:跨进程 code 供给必须把 FFI 地址符号化。**
- boot 既存 generic 哈希表:dwseq 名;init 新建分派表:kv 内容重建('ht,zo-named code 值以 (vector 'zo e s) 占位+B 延迟回填破"表需 codes、codes 需 extvec"死锁);**kv 含活闭包(expander 回调)的=运行态缓存,'ht-empty 空表冷启语义**。
- boot static tlc/symbol-cell(gen=7 tag=7,wrf 拒收):staddr(真 static,同构成立)。
- **kw/rmp intern 域(P3.1 三专项定律在 code 供给面复现)**:code 常量池里的 keyword(deserialize fill 指令按 eq 匹配!"bad fill encoding: '#:representative-scope-fill!")与 resolved-module-path(linklet 互连键,"not exported"×5)副本分裂→7 fail;外置 'kw/'rmp 语义名+B 桥 intern→7 fail 全消。
**验收状态**:pair 全链 11/11+**扩展 11/12**;唯一残余=sim 族(syntax/parse residual prefab 分裂,minimatch "#<sim:dots>")——'prefab 通道三处已建但**外置 rtd 引发读端流错位("malformed fasl closure",嫌疑=wrf-record 的 rtd 专用写路径绕过外置谓词而 bld 遵守→图表计数错位)**,P33_CF_PREFAB 门控关闭待归因。
**其它实测**:demand 裁剪 40289→8415 仅省 6% 字节(34.4→32.2MB)——被引 code 图即大头;B 相位 zo build+read ≈78ms(旧 97ms 重放+34ms 读,细测待做);OOM 双例(纯错指针随机死法)随 fentry 修复消失;**codes 线也有方差崩**(2 例/6 有效对,验收段 invalid memory,107 staddr 兜底 code 为重点嫌疑,与主段 21% 方差同型)。
**工程纪律新记**:fasl-write 外置谓词每 unique 对象恰询一次(bld+wrf 同询,collected 序=extvec 序=引擎既约);crash-learn 循环(attempt→first-irritant→forced 重试)是外置面探索的标准姿势;S_get_code_obj 返回**基对象**(自身已减 item_off,fasl.c 尾行),勿二次剥。
**下轮清单**:①prefab 流错位归因(fasl.ss wrf-record rtd 路径 vs 谓词交互)→12/12 ②codes 线方差(staddr 兜底 107 code 逐条验证)③B 相位细测+32MB 构成分析④稳定性批。

## 2026-09-16:codes 线 12/12 达成 + 抽签根因坐实(D145-D148)
**① prefab 归因反转(已验证)**:A 端自读四象限(P33_CF_SELFRD,prefab 开/关双 SELFRD-OK)证写端无流错位;prefab=1 整对复跑 **12/12 fail=0**——上轮 malformed 系方差撞崩,"wrf-record 绕谓词"假说证伪,'prefab 通道正确,门控已摘(kernel 谓词咨询点=bld-graph 首访问,external 登记进 table-hash,rtd 的 not-in-table 断言无碍——机制审读记录)。**codes.fasl 线至此与主段同级满分:11/11+12/12**。
**② 抽签根因坐实(已验证,三方案全测)**:6 对批 4 崩全同死法(malformed fasl closure @ build-from-codes)=确定性 A/B 抽签非杂方差。根因=**bdw-unnamed 的 107 个 static code 走了 staddr——主段规则链本就显式排除 code 于地址身份((not ($code? v))),code 区跨进程不同构**。三方案实测:(a)staddr=4/6 抽签崩、绿轮 12/12;(b)响亮 dummy=确定性但 2/11 世界塌(kw.rkt 族 transformer 在这 107 里且**真被调用**——'#%app unbound 全家桶复现);(c)**RETAIN 路方向数据极好:unnamed 107→3**(walk reloc 穿透收编),但 B 在 mark walk 段 invalid memory(RETAIN 下 walk 穿透与 boot mmap 区/悬垂交互,闸门级新工程)且枚举面变化(codes 40289→51000,命名空间整体位移)。
**当前定格**:恢复 (a) staddr 兜底(绿轮满分,抽签率~2/3 每对),'sdummy 通道保留为 spec-fail 兜底。**下一战役=RETAIN 支线**:修 B walk 的 invalid memory(dw-reloc-ok 闸门审计+新代码路径的 reloc 读检查)→unnamed→3→0,抽签根除;届时 codes 线 6/6 可期。
**工具沉淀**:P33_CF_SELFRD=1(A 端同进程自读,写端/B 端故障二分利器)、run-cf6.sh/run-cf-quad.sh/run-codefasl-{pf,rt}.sh。

## 🎯 2026-09-16:RETAIN 支线战役(D149-D152)——codes 线抽签根除,5/6 满分
**定位链(B-only 15 秒迭代)**:同一 RETAIN A 产物 B-only 3/3 崩=确定性 A 产物侧;'scode-addr 独立标签+B 端 $code? 验型把哑弹变响弹→**三毒槽全指认**(B 同 delta 处=string×2/vector×1,tag 7)——code 区跨进程不同构 3/3 实锤,毒对象不再进 fasl-read。
**杀招=孤岛内联(已验证)**:RETAIN 下无 bdw 名的 gen-7 code 自身 reloc 可读→pred 改「有 walk 名才外置,无名 fall through 原生内联」——bdw-unnamed **107→0**(104 收编+3 内联),地址通道对 code 全废('scode-addr/'sdummy 留作响亮护栏死代码)。非 RETAIN 下内联会在 wrf-code 响亮死→**RETAIN 成为 codes 线显式前提**。
**稳定性(6 对 RETAIN 批)**:5/6 全满分 11/11+12/12;1 崩在 **codes 读之前的 mark walk 段**(invalid memory,与 codes 通道解耦)=RETAIN 下 B walk 穿透触雷类(2/8 观测,原配方线方差家族亲戚)。**判定:code 供给通道抽签已根除**——凡进到 codes 读的对全数满分。
**下轮**:①RETAIN-walk 低频崩定位(walk 相 reloc 穿透与 boot mmap 区/收集时序;prog 相位抓取进 run-cfr6)②B 相位细测+32MB 构成③R3 微基准。

## 2026-09-16:低频崩排查轮(D153-D156)——定性收窄为 RETAIN×codes 交互,四假说证伪
**对照批裁决(已验证)**:B-only 12 次 codes=2 崩(均 acceptance 相位,invalid memory)、**zoreplay 同 RETAIN 12 次=0 崩**——纯 RETAIN 无罪,配方线 21% 方差另有其源;崩=**RETAIN×codes 供给交互**。附:lldb 下 40/40 零崩(禁/开 ASLR 皆然)=**环境敏感,布局抽签成分坐实**;复现只能裸跑。
**四假说证伪(全部读源+实测)**:
- kind-4 immediate 地址直传:census 实测 **kept 集 kind-4=0 条**——排除。
- icache:fasl 读端纪律完备(fasl_entry/bv_fasl_entry 尾部 S_flush_instruction_cache+code-write 括号;flush 区间由 **S_code 分配器自身登记**(alloc.c:1105 S_record_code_mod))——排除。
- 悬垂-dirty-sweep 统一模型:机理面成立(mkgc trace-code 对 retain 表全模式走表;static code 提升后表冻结)但 zoreplay 同 RETAIN 0/12 直接否定其为本崩主因——降级为背景隐患。
- 枚举面错位:RETAIN 下 A/B 同为 51000 宽口径,count-mismatch=0——排除。
**剩余差异面(下轮首查)**:codes 线独有=①3 个孤岛内联副本 code(B 执行的是 fasl 副本而非原生)②32MB 单图物化的对象代际/卡表形态③extvec 5278 外置解析对象与重放世界的等价性。**下轮设计=B 端 hybrid 交叉核对(P33_CF_XCHECK)**:B 同进程先 codes 建表、再 zo 重放建原生表,kept 槽位逐一对比解析对象类别/结构,确定性指认毒槽类(不再依赖 2/12 崩抽签)。
**GC 机理档案(本轮读源沉淀)**:mkgc.ss:1150-1176=code sweep 时 reloc 表逐项 trace+重打,static 提升时 retain 分支迁移表到 space_data 并保留;此后 static code 不再被 sweep,表冻结——retain 表的"悬垂"仅当表内目标于提升后再移动(boot vfasl 整批 to_static 场景下目标同批固定,故常态无悬垂;例外面待查)。

## 2026-09-16:低频崩深挖二轮(D157-D162)——审计线穷尽,定性收口
**新证据链(全已验证)**:
- f0 二分:fentry 全置 0 地址仍 3/24 崩(同 oks=0 形态)——**fentry 洗清**;顺带证明验收路径不执行那批 FFI。
- 崩位强聚集:oks=0(验收第一条 eval 内)为主体(5/6),尾段 1 例。
- GC 放大器反向:eval 前满代收集=8/8 全绿(**清场消雷**——崩需特定代际窗口);小 trip+checker=GC 时间 100% 不可行。
- **checker 现行抓捕 1 例**(gcs3#6):gen1 space-impure 槽→gen1 space-empty(整段已回收)"after gc"=堆内隐藏指针悬垂;from 邻域含 "<dummy" 字符串指纹(身份未定,resolver dummy 布线=0 排除该来源)。
- **lldb 活现场 1 例**:崩指令=pair 解引用序(ldur x30,[x0,#1]),x0=0x10502ffff 落 Racket 映像区——可能是悬垂对象读出的垃圾内容(与 checker 型统一)。
- **XCHECK v2/v3**(span 外机器码逐字节+span 内 patch 值合法性):8419 code **全零差**——静态可比面六维(结构/reloc 分类/单例 eq/字节/patch 值/间接类别)与原生完全等价。
- **checker 12 次零报告但 4/12 崩**:毒不在段扫描可见面;读源证实 space_code 亦在 check 覆盖(1926 行注释过时)——存活候选收敛到**栈/tc 根槽漏 trace 类**(checker 不扫栈;吻合执行态崩+零报告),其上游(rp 头在 span 外=v2 已证同)审读未见缺口。
- C 装备落地:gcwrapper checker 报告自带 from 邻域 9 词+目标残骸(自动取证),CHEZ_CHECK_HEAP_NO_ABORT=1 报告不杀模式。
**批间强相关性**:同二进制同配置,一批 6 连绿/一批 4 连崩——批级共享状态(非 A 产物;系统级布局种子嫌疑),复现须裸跑多批。
**定性收口(投入产出裁决)**:该崩=**实验装置(runtime-faslin code 供给)专属**;产品化 code 通道=build 期 vfasl 段装载,不经此管线,**产品形态下该 bug 自然消亡**。故记档存活候选与全套复现工具(run-f0/xcheck v1-3/hchk 系/lldb 取证脚本),不再无限深挖;codes 线以「5/6 满分+已定性低频 fail-stop 崩」状态服务后续实验,产品化推进优先。
