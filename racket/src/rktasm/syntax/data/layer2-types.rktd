;; ============================================================
;; Layer 2 操作数类型定义
;; ============================================================
;;
;; 共 21 种操作数类型，按类别分组

;; ------------------------------------------------------------
;; GPR (通用寄存器)
;; ------------------------------------------------------------

(gpr-64
  (description "64位通用寄存器")
  (patterns "XZR" "XUInteger" "X[0-9]+" "SP")
  (examples "X0" "X30" "XZR" "SP")
  (bit-width 64)
  (reg-range 0 31))

(gpr-32
  (description "32位通用寄存器")
  (patterns "WZR" "WUInteger" "W[0-9]+" "WSP")
  (examples "W0" "W30" "WZR" "WSP")
  (bit-width 32)
  (reg-range 0 31))

;; ------------------------------------------------------------
;; SIMD (向量/浮点寄存器)
;; ------------------------------------------------------------

(simd-scalar
  (description "SIMD标量寄存器")
  (patterns "BUInteger" "HUInteger" "SUInteger" "DUInteger" "QUInteger")
  (examples "B0" "H15" "S31" "D0" "Q7")
  (variants
    (B (bit-width 8))
    (H (bit-width 16))
    (S (bit-width 32))
    (D (bit-width 64))
    (Q (bit-width 128)))
  (reg-range 0 31))

(simd-vector
  (description "SIMD向量寄存器")
  (patterns "VUInteger.8B" "VUInteger.16B" "VUInteger.4H" "VUInteger.8H"
            "VUInteger.2S" "VUInteger.4S" "VUInteger.2D")
  (examples "V0.8B" "V15.4S" "V31.2D")
  (arrangements
    (8B  (elements 8)  (element-bits 8))
    (16B (elements 16) (element-bits 8))
    (4H  (elements 4)  (element-bits 16))
    (8H  (elements 8)  (element-bits 16))
    (2S  (elements 2)  (element-bits 32))
    (4S  (elements 4)  (element-bits 32))
    (2D  (elements 2)  (element-bits 64)))
  (reg-range 0 31))

(simd-element
  (description "SIMD向量元素访问")
  (patterns "VUInteger[UInteger]")
  (examples "V0[0]" "V15[3]")
  (reg-range 0 31)
  (index-range 0 15))

;; ------------------------------------------------------------
;; SVE (可伸缩向量扩展)
;; ------------------------------------------------------------

(sve-z
  (description "SVE Z向量寄存器")
  (patterns "ZUInteger" "ZUInteger.B" "ZUInteger.H" "ZUInteger.S" "ZUInteger.D")
  (examples "Z0" "Z31.B" "Z15.S")
  (element-sizes B H S D)
  (reg-range 0 31))

(sve-p
  (description "SVE P谓词寄存器")
  (patterns "PUInteger" "PUInteger/Z" "PUInteger/M" "PUInteger.B" "PUInteger.H" "PUInteger.S" "PUInteger.D")
  (examples "P0" "P7/Z" "P15/M" "P3.B")
  (modifiers
    (/Z "zeroing - 非活动元素置零")
    (/M "merging - 非活动元素保持"))
  (element-sizes B H S D)
  (reg-range 0 15))

(sve-pn
  (description "SVE PN谓词计数器寄存器")
  (patterns "PNUInteger" "PNUInteger/Z" "PNUInteger.B")
  (examples "PN0" "PN8/Z" "PN15.B")
  (modifiers
    (/Z "zeroing"))
  (reg-range 0 15))

;; ------------------------------------------------------------
;; SME (可伸缩矩阵扩展)
;; ------------------------------------------------------------

(sme-za
  (description "SME ZA矩阵寄存器")
  (patterns "ZA" "ZAUInteger.B" "ZAUInteger.H" "ZAUInteger.S" "ZAUInteger.D"
            "ZA.B[...]" "ZA.H[...]" "ZA.S[...]" "ZA.D[...]")
  (examples "ZA" "ZA0.S" "ZA.H[W0, 0]" "ZA0H.H[W12, 0:1]")
  (element-sizes B H S D Q)
  (tile-range 0 15))

(sme-zt
  (description "SME ZT查找表寄存器")
  (patterns "ZT0" "ZT0[UInteger]")
  (examples "ZT0" "ZT0[0]")
  (reg-range 0 0))

;; ------------------------------------------------------------
;; 立即数/常量
;; ------------------------------------------------------------

(immediate
  (description "整数立即数")
  (patterns "UInteger" "SInteger" "#[0-9]+" "#-[0-9]+")
  (examples "#0" "#16" "#-128" "UInteger" "SInteger")
  (variants
    (UInteger (signed #f) (description "无符号整数"))
    (SInteger (signed #t) (description "有符号整数"))))

(float-const
  (description "浮点常量")
  (patterns "Real" "0.0" "0.5" "1.0" "2.0")
  (examples "0.0" "0.5" "1.0" "Real")
  (known-values 0.0 0.5 1.0 2.0))

;; ------------------------------------------------------------
;; 关键字/修饰符
;; ------------------------------------------------------------

(keyword
  (description "移位和扩展关键字")
  (values
    ;; 移位操作
    (LSL "逻辑左移")
    (LSR "逻辑右移")
    (ASR "算术右移")
    (ROR "循环右移")
    (MSL "掩码移位左移")
    ;; 扩展操作
    (UXTB "无符号扩展字节")
    (UXTH "无符号扩展半字")
    (UXTW "无符号扩展字")
    (UXTX "无符号扩展双字")
    (SXTB "有符号扩展字节")
    (SXTH "有符号扩展半字")
    (SXTW "有符号扩展字")
    (SXTX "有符号扩展双字")
    ;; 其他
    (MUL "乘法修饰符")
    (VL "向量长度")))

(cond-code
  (description "条件码")
  (values
    (EQ "等于 (Z=1)")
    (NE "不等于 (Z=0)")
    (CS "进位设置 (C=1)") (HS "无符号大于等于")
    (CC "进位清除 (C=0)") (LO "无符号小于")
    (MI "负数 (N=1)")
    (PL "正数或零 (N=0)")
    (VS "溢出 (V=1)")
    (VC "无溢出 (V=0)")
    (HI "无符号大于")
    (LS "无符号小于等于")
    (GE "有符号大于等于")
    (LT "有符号小于")
    (GT "有符号大于")
    (LE "有符号小于等于")
    (AL "总是")
    (NV "从不")))

(barrier-option
  (description "内存屏障选项")
  (values
    (SY "完全系统屏障")
    (ST "仅存储屏障")
    (LD "仅加载屏障")
    (ISH "内部共享域")
    (ISHST "内部共享域-仅存储")
    (ISHLD "内部共享域-仅加载")
    (NSH "非共享域")
    (NSHST "非共享域-仅存储")
    (NSHLD "非共享域-仅加载")
    (OSH "外部共享域")
    (OSHST "外部共享域-仅存储")
    (OSHLD "外部共享域-仅加载")
    (CSYNC "上下文同步")
    (DSYNC "数据同步")
    (SYnXS "带nXS的完全屏障")))

(prefetch-op
  (description "预取操作")
  (values
    (PLDL1KEEP "L1预取-保持")
    (PLDL1STRM "L1预取-流式")
    (PLDL2KEEP "L2预取-保持")
    (PLDL2STRM "L2预取-流式")
    (PLDL3KEEP "L3预取-保持")
    (PLDL3STRM "L3预取-流式")
    (PLIL1KEEP "L1指令预取-保持")
    (PLIL1STRM "L1指令预取-流式")
    (PLIL2KEEP "L2指令预取-保持")
    (PLIL2STRM "L2指令预取-流式")
    (PLIL3KEEP "L3指令预取-保持")
    (PLIL3STRM "L3指令预取-流式")
    (PSTL1KEEP "L1预存-保持")
    (PSTL1STRM "L1预存-流式")
    (PSTL2KEEP "L2预存-保持")
    (PSTL2STRM "L2预存-流式")
    (PSTL3KEEP "L3预存-保持")
    (PSTL3STRM "L3预存-流式")
    (KEEP "保持")
    (STRM "流式")))

(vector-length
  (description "向量长度乘数")
  (values
    (VLx2 "向量长度×2")
    (VLx4 "向量长度×4")))

(pre-index
  (description "Pre-index寻址修饰符")
  (values
    (! "写回基址寄存器")))

;; ------------------------------------------------------------
;; 内存/列表
;; ------------------------------------------------------------

(memory
  (description "内存操作数")
  (patterns "[Xn]" "[Xn, #imm]" "[Xn, Xm]" "[Xn, Xm, LSL #n]" "[SP]" "[SP, #imm]")
  (examples "[X0]" "[SP, #16]" "[X1, X2]" "[X0, W1, SXTW]")
  (addressing-modes
    (base-only "[Xn|SP]")
    (base-imm "[Xn|SP, #imm]")
    (base-reg "[Xn|SP, Xm]")
    (base-reg-shift "[Xn|SP, Xm, LSL #n]")
    (base-reg-extend "[Xn|SP, Wm, SXTW]")))

(reg-list
  (description "寄存器列表")
  (patterns "{Vn.T}" "{Vn.T, Vm.T}" "{Vn.T-Vm.T}" "{Zn.T}" "{Zn.T-Zm.T}")
  (examples "{V0.8B}" "{V0.4S, V1.4S}" "{Z0.B-Z3.B}" "{V0.8B-V3.8B}")
  (list-types
    (consecutive "{Vn-Vm}" "连续寄存器范围")
    (explicit "{Vn, Vm, ...}" "显式列表")))

;; ------------------------------------------------------------
;; 系统相关
;; ------------------------------------------------------------

(system-reg
  (description "系统寄存器")
  (patterns "UAO" "PAN" "DIT" "SSBS" "TCO" "ACTLR_EL3" "CUInteger")
  (examples "UAO" "PAN" "ACTLR_EL3" "SCTLR_EL1")
  (categories
    (pstate "处理器状态" (UAO PAN DIT SSBS TCO))
    (control "控制寄存器" (ACTLR SCTLR CPACR))
    (exception "异常寄存器" (SPSR ELR ESR FAR))
    (memory "内存寄存器" (MAIR TCR TTBR))
    (numbered "编号寄存器" (CUInteger))))
