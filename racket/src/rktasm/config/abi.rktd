;; ============================================================
;; ABI 配置文件
;; ============================================================
;;
;; 新配置格式:
;;   (gpr (num-regs N) (banned BITS) (preserved BITS) (args 0 1 ...) (return 0))
;;   (fpr ...)
;;   (pred ...)
;;   (extends parent-name)
;;   (special-regs (sp 31) (fp 29) ...)
;;
;; 旧配置格式（向后兼容）:
;;   (class num-regs banned preserved)
;;
;;   num-regs:  寄存器总数
;;   banned:    位域, 禁止分配
;;   preserved: 位域, callee-saved
;;   args:      参数寄存器列表
;;   return:    返回寄存器列表

;; 标准 ARM64 ABI (AAPCS64)
(aapcs64
  (gpr
    (num-regs 31)
    (banned #x70000)           ; x16/x17 为重写器临时寄存器，x18 平台保留
    (preserved #x7FF80000)     ; x19-x30 callee-saved
    (args 0 1 2 3 4 5 6 7)     ; x0-x7 参数
    (return 0))                ; x0 返回值
  (fpr
    (num-regs 32)
    (banned #x0)
    (preserved #xFF00)         ; v8-v15 callee-saved
    (args 0 1 2 3 4 5 6 7)     ; v0-v7 参数
    (return 0 1))              ; v0-v1 返回值
  (pred
    (num-regs 16)
    (banned #x0)
    (preserved #x0)            ; 全部 caller-saved
    (args 0 1 2 3)             ; p0-p3 SVE predicate 参数/结果
    (return 0 1 2 3))          ; p0-p3 SVE predicate 参数/结果
  (special-regs
    (sp 31) (fp 29) (lr 30) (platform 18)))

;; 叶函数 - 继承 aapcs64，覆盖部分配置
(leaf
  (extends aapcs64)
  (gpr
    (num-regs 31)
    (banned #x70000)
    (preserved #x1FF80000)))   ; 只保存 x19-x28 (无 x29/x30)

;; 裸函数 - 完全手动控制
(naked
  (gpr
    (num-regs 31)
    (banned #x30000)           ; x16/x17 为重写器临时寄存器
    (preserved #x0)
    (args 0 1 2 3 4 5 6 7)
    (return 0))
  (fpr
    (num-regs 32)
    (banned #x0)
    (preserved #x0)
    (args 0 1 2 3 4 5 6 7)
    (return 0 1))
  (pred
    (num-regs 16)
    (banned #x0)
    (preserved #x0)
    (args 0 1 2 3)
    (return 0 1 2 3))
  (special-regs
    (sp 31) (fp 29) (lr 30) (platform 18)))

;; 宽参数 ABI - 用于寄存器传参的热点内核 (如 P-256 域乘 8 入 4 出 = 12 槽)
;; leaf 风格(不保存 callee-saved),参数寄存器扩到 x0-x13,返回 x0-x3。
(wideargs
  (extends aapcs64)
  (gpr
    (num-regs 31)
    (banned #x7FFF0000)        ; 只用 x0-x15 (全 caller-saved);禁 x16-x30 以保持 C ABI 一致
    (preserved #x0)            ; leaf 风格, 无 save/restore
    (args 0 1 2 3 4 5 6 7 8 9 10 11 12 13)   ; x0-x13 参数槽 (14 个, 覆盖 12)
    (return 0 1 2 3))          ; x0-x3 返回值
  (fpr
    (num-regs 32)
    (banned #xFF00)            ; 禁 v8-v15 (callee-saved);溢出用 v16-v31 (caller-saved)
    (preserved #x0)
    (args 0 1 2 3 4 5 6 7)
    (return 0 1))
  (pred
    (num-regs 16)
    (banned #x0)
    (preserved #x0)
    (args 0 1 2 3)
    (return 0 1 2 3))
  (special-regs
    (sp 31) (fp 29) (lr 30) (platform 18)))

;; 域加/减轻量 ABI - 保留 x4-x7 (域乘前向取数载体)，供 clobber-aware 让前向
;; 载入的域乘操作数跨越 add/sub 调用存活。12 参数槽 = x0-x3 + x8-x15。
(fieldadd
  (gpr
    (num-regs 31)
    (banned #x70000)           ; x16/x17/x18
    (preserved #x7FF800F0)     ; x4-x7 + x19-x30 保留；caller-saved = x0-x3,x8-x15
    (args 0 1 2 3 8 9 10 11 12 13 14 15)   ; 8 输入 x0-x3,x8-x11 + 4 输出 x12-x15
    (return 12 13 14 15))
  (fpr
    (num-regs 32)
    (banned #xFF00)
    (preserved #x0)
    (args 0 1 2 3 4 5 6 7)
    (return 0 1))
  (pred
    (num-regs 16)
    (banned #x0)
    (preserved #x0)
    (args 0 1 2 3)
    (return 0 1 2 3))
  (special-regs
    (sp 31) (fp 29) (lr 30) (platform 18)))

;; OpenSSL ecp_nistz256 域运算约定 (手工调度对标): 结果恒在 x14-x17,
;; 域乘 a=x4-x7 / b 经指针 x2, 域加 a=x14-x17 / b=x8-x11, 域减 a=x14-x17 / b 指针 x2。
;; 子例程 clobber x0-x20 (x19/x20 作 scratch, 由 point_double 序言 save),
;; 保留 x21-x30 (rp/pp/帧/lr)。用于 result-bank flow + forward-load 重叠。
(omul2  ; 多 bank 域乘(vreg point_double 用): a=x4-x7, bp=x2, out=x14-x17
  (gpr (num-regs 31) (banned #x40001) (preserved #x7FE00000)
    (args 4 5 6 7 2 14 15 16 17) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))
(omul   ; 域乘: a=x4-x7,bp=x2,out=x14-x17; x0 保留输出指针
  (gpr (num-regs 31) (banned #x40001) (preserved #x7FE00000)
    (args 4 5 6 7 3 2 14 15 16 17) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))
(osqr   ; 平方: a=x4-x7,out=x14-x17; x0 保留输出指针
  (gpr (num-regs 31) (banned #x40001) (preserved #x7FE00000)
    (args 4 5 6 7 14 15 16 17) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))
(oadd   ; 域加: a=x14-x17,b=x8-x11,out=x14-x17,rp=x0; x3-x7 保留(前向取数)
  (gpr (num-regs 31) (banned #x400F8) (preserved #x7FE00000)
    (args 14 15 16 17 8 9 10 11 0) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))
(osubp  ; 域减: a=x14-x17,bp=x2,rp=x0; x3-x7 保留(前向取数)
  (gpr (num-regs 31) (banned #x400F8) (preserved #x7FE00000)
    (args 14 15 16 17 2 0) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))
(oun    ; div2: a=x14-x17,rp=x0; x3-x7 保留(前向取数)
  (gpr (num-regs 31) (banned #x400F8) (preserved #x7FE00000)
    (args 14 15 16 17 0) (return 14 15 16 17))
  (fpr (num-regs 32) (banned #xFF00) (preserved #x0) (args 0 1 2 3 4 5 6 7) (return 0 1))
  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 0 1 2 3) (return 0 1 2 3))
  (special-regs (sp 31) (fp 29) (lr 30) (platform 18)))

;; 保留型 ABI 测试样例 - 只 clobber x0-x3，保留 x4-x15/x19-x30。
;; 用于验证 clobber-aware 跨调用分配：调用方可把跨调用值放进被调方保留的
;; caller-saved 寄存器 (x4-x15)，无需进 callee-saved 或溢出。
(tinyclob
  (gpr
    (num-regs 31)
    (banned #x70000)           ; x16/x17/x18
    (preserved #x7FF8FFF0)     ; x4-x15, x19-x30 保留 => caller-saved 仅 x0-x3
    (args 0 1 2 3)
    (return 0))
  (fpr
    (num-regs 32)
    (banned #x0)
    (preserved #xFF00)
    (args 0 1 2 3 4 5 6 7)
    (return 0 1))
  (pred
    (num-regs 16)
    (banned #x0)
    (preserved #x0)
    (args 0 1 2 3)
    (return 0 1 2 3))
  (special-regs
    (sp 31) (fp 29) (lr 30) (platform 18)))

;; 自定义 ABI 示例 - 只用 4 个参数寄存器
;; (my-abi
;;   (extends aapcs64)
;;   (gpr
;;     (num-regs 31)
;;     (banned #x40100)         ; 禁用 x18 和 x8
;;     (args 0 1 2 3)))         ; 只用 4 个参数寄存器
