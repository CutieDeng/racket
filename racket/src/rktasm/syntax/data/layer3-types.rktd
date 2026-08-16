;; ============================================================
;; Layer 3 约束类型定义
;; ============================================================
;;
;; 共 6 种约束类型，用于细粒度操作数验证
;;

;; ------------------------------------------------------------
;; 寄存器范围约束 (reg-range)
;; ------------------------------------------------------------

(reg-range
  (description "寄存器编号范围约束")
  (fields min max)
  (examples
    (gpr-full    (reg-range 0 31))   ; 5-bit 通用寄存器
    (gpr-mid     (reg-range 0 15))   ; 4-bit 通用寄存器
    (gpr-low     (reg-range 0 7))    ; 3-bit 低位寄存器
    (gpr-pair    (reg-range 0 3))    ; 2-bit 寄存器对
    (sve-z-full  (reg-range 0 31))   ; SVE Z 完整范围
    (sve-z-mid   (reg-range 0 15))   ; SVE Z 4-bit 范围
    (sve-z-low   (reg-range 0 7))    ; SVE Z 3-bit 范围
    (sve-p-full  (reg-range 0 15))   ; SVE P 谓词 4-bit
    (sve-p-low   (reg-range 0 7))    ; SVE P 控制谓词 3-bit
    (simd-full   (reg-range 0 31)))  ; SIMD 完整范围
  (validation
    "检查寄存器编号 n 是否满足 min <= n <= max"))

;; ------------------------------------------------------------
;; 立即数范围约束 (imm-range)
;; ------------------------------------------------------------

(imm-range
  (description "立即数范围约束")
  (fields min max step)
  (examples
    (imm3    (imm-range 0 7 1))       ; 3-bit 立即数 0-7
    (imm4    (imm-range 0 15 1))      ; 4-bit 立即数 0-15
    (imm5    (imm-range 0 31 1))      ; 5-bit 立即数 0-31
    (imm6    (imm-range 0 63 1))      ; 6-bit 立即数 0-63
    (imm7    (imm-range 0 127 1))     ; 7-bit 立即数 0-127
    (imm8    (imm-range 0 255 1))     ; 8-bit 立即数 0-255
    (imm9    (imm-range 0 511 1))     ; 9-bit 立即数 0-511
    (imm12   (imm-range 0 4095 1))    ; 12-bit 立即数 0-4095
    (imm16   (imm-range 0 65535 1))   ; 16-bit 立即数 0-65535
    (imm19   (imm-range 0 524287 1))) ; 19-bit 立即数 0-524287
  (validation
    "检查立即数 v 是否满足 min <= v <= max 且 (v - min) % step == 0"))

;; ------------------------------------------------------------
;; 特定立即数值约束 (imm-values)
;; ------------------------------------------------------------

(imm-values
  (description "特定立即数值列表约束")
  (fields values)
  (examples
    (shift-types (imm-values 0 1 2 3))  ; LSL, LSR, ASR, ROR
    (bool-flag   (imm-values 0 1)))     ; 0 或 1
  (validation
    "检查立即数是否在允许的值列表中"))

;; ------------------------------------------------------------
;; 向量排列约束 (arrangement)
;; ------------------------------------------------------------

(arrangement
  (description "SIMD 向量排列约束")
  (fields arrangements)
  (examples
    (simd-byte    (arrangement 8B 16B))    ; 字节排列
    (simd-half    (arrangement 4H 8H))     ; 半字排列
    (simd-single  (arrangement 2S 4S))     ; 单精度排列
    (simd-double  (arrangement 2D))        ; 双精度排列
    (simd-all     (arrangement 8B 16B 4H 8H 2S 4S 2D)))
  (validation
    "检查向量排列是否在允许的列表中"))

;; ------------------------------------------------------------
;; 元素大小约束 (element-size)
;; ------------------------------------------------------------

(element-size
  (description "SVE/SME 元素大小约束")
  (fields sizes)
  (examples
    (sve-bhsd (element-size B H S D))   ; 所有大小
    (sve-hsd  (element-size H S D))     ; 半字及以上
    (sve-sd   (element-size S D))       ; 单/双精度
    (sve-d    (element-size D)))        ; 仅双精度
  (element-meanings
    (B "Byte - 8位")
    (H "Halfword - 16位")
    (S "Single - 32位")
    (D "Double - 64位")
    (Q "Quad - 128位"))
  (validation
    "检查元素大小是否在允许的列表中"))

;; ------------------------------------------------------------
;; 谓词模式约束 (pred-mode)
;; ------------------------------------------------------------

(pred-mode
  (description "SVE 谓词模式约束")
  (fields modes)
  (examples
    (zeroing (pred-mode z))       ; 仅 /Z 模式
    (merging (pred-mode m))       ; 仅 /M 模式
    (either  (pred-mode z m)))    ; 两种模式都可
  (mode-meanings
    (z "Zeroing - 非活动元素置零")
    (m "Merging - 非活动元素保持原值"))
  (validation
    "检查谓词模式是否在允许的列表中"))

;; ============================================================
;; 约束统计 (从 4288 条指令提取)
;; ============================================================

(statistics
  (寄存器范围约束
    ((reg-range 0 31) 8462 "最常见的完整 GPR/SIMD/SVE-Z 范围")
    ((reg-range 0 7) 1638 "3-bit 低位寄存器或控制谓词")
    ((reg-range 0 15) 877 "4-bit 中位寄存器或完整谓词")
    ((reg-range 0 3) 86 "2-bit 寄存器对"))
  (立即数范围约束
    ((imm-range 0 7) 238 "3-bit 立即数")
    ((imm-range 0 15) 230 "4-bit 立即数")
    ((imm-range 0 511) 159 "9-bit 带符号偏移")
    ((imm-range 0 3) 117 "2-bit 立即数")
    ((imm-range 0 63) 94 "6-bit 立即数")
    ((imm-range 0 31) 70 "5-bit 立即数")
    ((imm-range 0 127) 66 "7-bit 立即数")
    ((imm-range 0 4095) 32 "12-bit 无符号偏移")
    ((imm-range 0 255) 29 "8-bit 立即数")
    ((imm-range 0 65535) 19 "16-bit 立即数")
    ((imm-range 0 524287) 13 "19-bit PC 相对偏移"))
  (常用字段
    (Rn 2481 "基址/源寄存器")
    (Zn 1246 "SVE 源向量")
    (Rd 1151 "目标寄存器")
    (Zm 1114 "SVE 第二源向量")
    (Rt 890 "传输寄存器")
    (size 834 "元素大小")
    (Rm 792 "第三源寄存器")
    (Pg 780 "控制谓词")))
