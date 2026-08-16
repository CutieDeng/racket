;; ============================================================
;; Layer 3 约束统计摘要
;; ============================================================

;; --- 寄存器范围约束 ---
;; (reg-range 0 15): 877 次
;; (reg-range 0 7): 1638 次
;; (reg-range 0 31): 8462 次
;; (reg-range 0 3): 86 次

;; --- 立即数范围约束 ---
;; (imm-range 0 1048572): 13 次
;; (imm-range 0 255): 29 次
;; (imm-range 0 15): 230 次
;; (imm-range 0 4095): 32 次
;; (imm-range 0 63): 94 次
;; (imm-range 0 31): 70 次
;; (imm-range 0 65535): 19 次
;; (imm-range 0 7): 238 次
;; (imm-range 0 255): 159 次
;; (imm-range 0 3): 117 次
;; (imm-range 0 63): 66 次

;; --- 字段使用统计 (top 30) ---
;; Rn: 2481 次
;; Zn: 1246 次
;; Rd: 1151 次
;; Zm: 1114 次
;; Rt: 890 次
;; size: 834 次
;; Rm: 792 次
;; Pg: 780 次
;; Rs: 555 次
;; Zd: 529 次
;; Zt: 454 次
;; Zdn: 261 次
;; imm4: 223 次
;; off3: 176 次
;; Zda: 164 次
;; imm9: 159 次
;; PNg: 128 次
;; Rt2: 117 次
;; Pd: 104 次
;; off2: 86 次
;; Pn: 84 次
;; Pm: 82 次
;; imm5: 67 次
;; imm6: 66 次
;; imm7: 66 次
;; imm3: 56 次
;; Rdn: 52 次
;; imm12: 32 次
;; Vd: 29 次
;; imm8: 29 次

;; === 常用约束模板 ===

(common-constraints
  ;; GPR 范围
  (gpr-full (reg-range 0 31))     ; 5-bit 寄存器
  (gpr-low  (reg-range 0 7))      ; 3-bit 寄存器
  (gpr-mid  (reg-range 0 15))     ; 4-bit 寄存器

  ;; SVE Z 范围
  (sve-z-full (reg-range 0 31))   ; 5-bit
  (sve-z-low  (reg-range 0 7))    ; 3-bit (某些指令)
  (sve-z-mid  (reg-range 0 15))   ; 4-bit (某些指令)

  ;; SVE P 谓词范围
  (sve-p-full (reg-range 0 15))   ; 4-bit
  (sve-p-low  (reg-range 0 7))    ; 3-bit (控制谓词)

  ;; 常见立即数范围
  (imm3 (imm-range 0 7 1))        ; 3-bit
  (imm4 (imm-range 0 15 1))       ; 4-bit
  (imm5 (imm-range 0 31 1))       ; 5-bit
  (imm6 (imm-range 0 63 1))       ; 6-bit
  (imm8 (imm-range 0 255 1))      ; 8-bit
)
