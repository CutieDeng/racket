("SME FP64 outer product" ("sme" "sme outer product" "64 bit")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (ZAda 3)))
("SME Int16 outer product" ("sme" "sme outer product" "64 bit")
  ((_ 2) (_ 5) (u0 1) (_ 2) (u1 1) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (ZAda 3)))
("SME FP32 outer product" ("sme" "sme fp outer product" "32 bit")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME BF16 widening outer product" ("sme" "sme fp outer product" "32 bit")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME FP16 widening outer product" ("sme" "sme fp outer product" "32 bit")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME2 32-bit binary outer product" ("sme" "sme2 outer product" "misc")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME2 FP16 non-widening outer product" ("sme" "sme2 outer product" "misc")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 2) (ZAda 1)))
("SME2 BF16 non-widening outer product" ("sme" "sme2 outer product" "misc")
  ((_ 2) (_ 9) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 2) (ZAda 1)))
("SME2 Int16 two-way outer product" ("sme" "sme integer outer product" "32 bit")
  ((_ 2) (_ 5) (u0 1) (_ 3) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME2 Int8 outer product" ("sme" "sme integer outer product" "32 bit")
  ((_ 2) (_ 5) (u0 1) (_ 2) (u1 1) (Zm 5) (Pm 3) (Pn 3) (Zn 5) (S 1) (_ 1) (_ 1) (ZAda 2)))
("SME2 multi-vec contiguous load (scalar plus scalar, two registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 4) (N 1)))
("SME2 multi-vec contiguous load (scalar plus scalar, four registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 3) (_ 1) (N 1)))
("SME2 multi-vec contiguous store (scalar plus scalar, two registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 4) (N 1)))
("SME2 multi-vec contiguous store (scalar plus scalar, four registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 3) (_ 1) (N 1)))
("SME2 multi-vec contiguous load (scalar plus immediate, two registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 4) (N 1)))
("SME2 multi-vec contiguous load (scalar plus immediate, four registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 3) (_ 1) (N 1)))
("SME2 multi-vec contiguous store (scalar plus immediate, two registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 4) (N 1)))
("SME2 multi-vec contiguous store (scalar plus immediate, four registers)" ("sme" "sme2 multi-vector" "memory" "contiguous")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zt 3) (_ 1) (N 1)))
("SME2 multi-vec non-contiguous load (scalar plus scalar, two registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (Ztl 3)))
("SME2 multi-vec non-contiguous load (scalar plus scalar, four registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (_ 1) (Ztl 2)))
("SME2 multi-vec non-contiguous store (scalar plus scalar, two registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (Ztl 3)))
("SME2 multi-vec non-contiguous store (scalar plus scalar, four registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 11) (Rm 5) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (_ 1) (Ztl 2)))
("SME2 multi-vec non-contiguous load (scalar plus immediate, two registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (Ztl 3)))
("SME2 multi-vec non-contiguous load (scalar plus immediate, four registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (_ 1) (Ztl 2)))
("SME2 multi-vec non-contiguous store (scalar plus immediate, two registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (Ztl 3)))
("SME2 multi-vec non-contiguous store (scalar plus immediate, four registers)" ("sme" "sme2 multi-vector" "strided")
  ((_ 12) (imm4 4) (_ 1) (msz 2) (PNg 3) (Rn 5) (Zth 1) (N 1) (_ 1) (Ztl 2)))
("SME move vector to array" ("sme" "sme move into array")
  ((_ 8) (size 2) (_ 5) (Q 1) (V 1) (Rs 2) (Pg 3) (Zn 5) (_ 1) (opc 4)))
("SME2 move vector to tile, two registers" ("sme" "sme move into array")
  ((_ 2) (_ 6) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (Zn 4) (_ 2) (_ 1) (opc 3)))
("SME2 move vector to tile, four registers" ("sme" "sme move into array")
  ((_ 2) (_ 6) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (Zn 3) (_ 3) (_ 1) (opc 3)))
("SME zeroing move array to vector" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 5) (Q 1) (V 1) (Rs 2) (_ 3) (_ 1) (opc 4) (Zd 5)))
("SME move array to vector" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 5) (Q 1) (V 1) (Rs 2) (Pg 3) (_ 1) (opc 4) (Zd 5)))
("SME2 move tile to vector, two registers" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (_ 2) (opc 3) (Zd 4) (_ 1)))
("SME2 zeroing move tile to vector, two registers" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (_ 2) (opc 3) (Zd 4) (_ 1)))
("SME2 move tile to vector, four registers" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (_ 2) (opc 3) (Zd 3) (_ 2)))
("SME2 zeroing move tile to vector, four registers" ("sme" "sme move from array")
  ((_ 8) (size 2) (_ 6) (V 1) (Rs 2) (_ 3) (_ 2) (opc 3) (Zd 3) (_ 2)))
("SME add vector to array" ("sme" "sme add vector to array")
  ((_ 2) (_ 7) (op 1) (_ 5) (V 1) (Pm 3) (Pn 3) (Zn 5) (_ 1) (_ 1) (opc2 3)))
("SME2 Multiple vectors zero array" ("sme" "sme zero" "sme2 multiple zero")
  ((_ 2) (_ 12) (opc 3) (Rv 2) (_ 3) (_ 6) (_ 1) (opc2 3)))
("SME2 zero lookup table" ("sme" "sme2 zero lookup table")
  ((_ 22) (_ 6) (opc 4)))
("SME2 move from lookup table" ("sme" "sme2 move lookup table")
  ((_ 17) (imm3 3) (opc 7) (Rt 5)))
("SME2 move into lookup table" ("sme" "sme2 move lookup table")
  ((_ 17) (imm3 3) (opc 7) (Rt 5)))
("SME2 lookup table expand four contiguous registers" ("sme" "sme2 expand lookup table" "contiguous")
  ((_ 13) (opc 3) (_ 2) (size 2) (opc2 2) (Zn 5) (Zd 3) (_ 2)))
("SME2 lookup table expand two contiguous registers" ("sme" "sme2 expand lookup table" "contiguous")
  ((_ 13) (opc 4) (_ 1) (size 2) (opc2 2) (Zn 5) (Zd 4) (_ 1)))
("SME2 lookup table expand one register" ("sme" "sme2 expand lookup table" "contiguous")
  ((_ 13) (opc 5) (size 2) (opc2 2) (Zn 5) (Zd 5)))
("SME2 lookup table expand four non-contiguous registers" ("sme" "sme2 expand lookup table" "non-contiguous")
  ((_ 2) (_ 10) (_ 1) (opc 3) (_ 2) (size 2) (opc2 2) (Zn 5) (Zdh 1) (_ 1) (_ 1) (Zdl 2)))
("SME2 lookup table expand two non-contiguous registers" ("sme" "sme2 expand lookup table" "non-contiguous")
  ((_ 2) (_ 11) (opc 4) (_ 1) (size 2) (opc2 2) (Zn 5) (Zdh 1) (_ 1) (Zdl 3)))
("SME2 multi-vec indexed long long MLA one source 32-bit" ("sme" "sme2 multi-vector" "indexed" "one register")
  ((_ 12) (Zm 4) (i4h 1) (Rv 2) (i4l 3) (Zn 5) (U 1) (S 1) (op 1) (off2 2)))
("SME2 multi-vec indexed long long MLA one source 64-bit" ("sme" "sme2 multi-vector" "indexed" "one register")
  ((_ 12) (Zm 4) (i3h 1) (Rv 2) (_ 1) (i3l 2) (Zn 5) (U 1) (S 1) (_ 1) (off2 2)))
("SME2 multi-vec indexed long FMA one source" ("sme" "sme2 multi-vector" "indexed" "one register")
  ((_ 12) (Zm 4) (i3h 1) (Rv 2) (_ 1) (i3l 2) (Zn 5) (op 1) (S 1) (off3 3)))
("SME2 multi-vec indexed long MLA one source" ("sme" "sme2 multi-vector" "indexed" "one register")
  ((_ 12) (Zm 4) (i3h 1) (Rv 2) (_ 1) (i3l 2) (Zn 5) (U 1) (S 1) (off3 3)))
("SME2 multi-vec indexed long long MLA two sources 32-bit" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 1) (i4h 2) (Zn 4) (op 1) (U 1) (S 1) (i4l 2) (o1 1)))
("SME2 multi-vec ternary indexed two registers 16-bit" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 1) (i3h 2) (Zn 4) (op 1) (S 1) (i3l 1) (off3 3)))

("SME2 multi-vec ternary indexed two registers 32-bit" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (op 1) (i2 2) (Zn 4) (opc2 3) (off3 3)))

("SME2 multi-vec indexed long long MLA two sources 64-bit" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 2) (i3h 1) (Zn 4) (_ 1) (U 1) (S 1) (i3l 2) (o1 1)))
("SME2 multi-vec indexed long FMA two sources" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 1) (i3h 2) (Zn 4) (_ 1) (op 1) (S 1) (i3l 1) (off2 2)))

("SME2 multi-vec ternary indexed two registers 64-bit" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 2) (i1 1) (Zn 4) (_ 1) (opc 2) (off3 3)))
("SME2 multi-vec indexed long MLA two sources" ("sme" "sme2 multi-vector" "indexed" "two registers")
  ((_ 12) (Zm 4) (_ 1) (Rv 2) (_ 1) (i3h 2) (Zn 4) (_ 1) (U 1) (S 1) (i3l 1) (off2 2)))

; SME2 Multi-vector - Indexed (Four registers)

; SME2 Multi-vector - SVE select
; 2

; SME2 Multi-vector - SVE Constructive Binary
; 8

; SME2 Multi-vector - SVE Constructive Unary
; 14

; SME2 Multi-vector - Multiple Vectors SVE Destructive (Two registers)
; 3

; SME2 Multi-vector - Multiple Vectors SVE Saturating Multiply (Two registers)
; 1

; SME2 Multi-vector - Multiple Vectors SVE Destructive (Four registers)
; 3

; SME2 Multi-vector - Multiple Vectors SVE Saturating Multiply (Four registers)
; 1

; SME2 Multi-vector - Multiple and Single SVE Destructive (Two registers)
; 5

; SME2 Multi-vector - Multiple and Single SVE Destructive (Four registers)
; 5

; SME2 Multi-vector - Multiple and Single Array Vectors (Two registers)
; 13

; SME2 Multi-vector - Multiple and Single Array Vectors (Four registers)
; 10

; SME2 Multi-vector - Multiple Array Vectors (Two registers)
; 13

; SME2 Multi-vector - Multiple Array Vectors (Four registers)
; 13

; SME2 Memory
; 6
