;; asmp 调度器微架构模型：Apple M 近似（默认模型）。
;; 与 pipeline/sched-model.rkt 的内置 apple-m 逐值一致；改此文件即改调度模型，
;; 或复制为 data/<name>.rktd 后用 --sched-model <name> / ASMP_SCHED_MODEL 选择。
;; 延迟单位 = 周期；端口容量 = 每周期该类端口可发射条数。
((name . apple-m)
 (issue-width . 3)
 (call-latency . 12)
 (default-latency . 1)
 (default-port . int)
 (default-port-capacity . 4)
 (latencies
  ((mul umulh madd msub mneg smull umull) . 3)
  ((ldr ldp ldur ldrb ldrh ldrsw) . 4)
  ((str stp stur strb strh) . 1)
  ;; AES round + mix：aese;aesmc 背靠背融合，crypto 管线各 ~2 cyc；
  ;; 无进位乘是长杆 ~3 cyc
  ((aese aesd aesmc aesimc) . 2)
  ((pmull pmull2) . 3)
  ((ld1 ld2 ld3 ld4 ldnp) . 4)
  ((st1 st2 st3 st4 stnp) . 1)
  ;; 向量 ALU / permute / dup / moves ~2 cyc，廉价逻辑 ~1
  ((add sub mla mls shl sshr ushr sli sri ext tbl tbx zip1 zip2 uzp1 uzp2
    trn1 trn2 dup ins rev16 rev32 rev64 rbit cnt) . 2)
  ((and orr eor bic orn eor3 bcax not mov movi mvni fmov) . 1))
 (ports
  ;; Apple M 上 AES 与 PMULL 共享 crypto 管线（实测几乎不重叠）→ 同端口
  ((aese aesd aesmc aesimc pmull pmull2) . crypto)
  ((ldr ldp ldur ldrb ldrh ldrsw ld1 ld2 ld3 ld4 ldnp) . ld)
  ((str stp stur strb strh st1 st2 st3 st4 stnp) . st)
  ((mul umulh madd msub mneg smull umull) . mul)
  ((add sub mla mls shl sshr ushr sli sri ext tbl tbx zip1 zip2 uzp1 uzp2
    trn1 trn2 dup ins rev16 rev32 rev64 rbit cnt
    and orr eor bic orn eor3 bcax not mov movi mvni fmov) . simd))
 (port-capacities
  (crypto . 1) (ld . 3) (st . 2) (mul . 2) (simd . 4) (int . 6)))
