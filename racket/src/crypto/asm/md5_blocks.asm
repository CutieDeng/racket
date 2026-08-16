;; Multi-block MD5 compress, hand-scheduled (OpenSSL md5-aarch64 schedule; clang
;; schedules the serial a-chain ~7% worse on Apple M). Registers are algorithm
;; roles: a/b/c/d state, m0..15 message words, k<n> constants, f<n> aux-function
;; temps, acc<n> add-chain accumulator; asmp does register allocation. ~69 ns/block.
;; History: a one-time transcriber (gen_md5.py, removed in Phase F) lifted the
;; OpenSSL md5-aarch64.pl hand schedule; the A2 pass then renamed it in place to
;; algorithm roles (pure SSA rename, instruction schedule byte-for-byte, gated
;; 0/200000 differential) — this .asm has been the canonical source ever since.
.function md5_blocks_asm export (
  in: x.st, x.data, x.num
)
entry:
  .save all
  ldp	w.a, w.b, [x.st, #0]    ; Load MD5 state->A and state->B
  ldp	w.c, w.d, [x.st, #8]    ; Load MD5 state->C and state->D
loop:
  eor	x.f1, x.c, x.d    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  and	x.f2, x.f1, x.b    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  ldp	w.m0, w.m1, [x.data]    ; Load 2 words of input data0 M[0],M[1]
  ldp	w.m2, w.m3, [x.data, #8]    ; Load 2 words of input data0 M[2],M[3]
  eor	x.f3, x.f2, x.d    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k1, #0xa478    ; Load lower half of constant 0xd76aa478
  movk	x.k1, #0xd76a, lsl #16    ; Load upper half of constant 0xd76aa478
  add	w.acc1, w.a, w.m0    ; Add dest value
  add	w.acc2, w.acc1, w.k1    ; Add constant 0xd76aa478
  add	w.acc3, w.acc2, w.f3    ; Add aux function result
  ror	w.acc4, w.acc3, #25    ; Rotate left s=7 bits
  eor	x.f4, x.b, x.c    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.a1, w.b, w.acc4    ; Add X parameter round 1 A=FF(A, B, C, D, 0xd76aa478, s=7, M[0])
  and	x.f5, x.f4, x.a1    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f6, x.f5, x.c    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k2, #0xb756    ; Load lower half of constant 0xe8c7b756
  movk	x.k2, #0xe8c7, lsl #16    ; Load upper half of constant 0xe8c7b756
  add	w.acc5, w.d, w.m1    ; Add dest value
  add	w.acc6, w.acc5, w.k2    ; Add constant 0xe8c7b756
  add	w.acc7, w.acc6, w.f6    ; Add aux function result
  ror	w.acc8, w.acc7, #20    ; Rotate left s=12 bits
  eor	x.f7, x.a1, x.b    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.d1, w.a1, w.acc8    ; Add X parameter round 1 D=FF(D, A, B, C, 0xe8c7b756, s=12, M[1])
  and	x.f8, x.f7, x.d1    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f9, x.f8, x.b    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k3, #0x70db    ; Load lower half of constant 0x242070db
  movk	x.k3, #0x2420, lsl #16    ; Load upper half of constant 0x242070db
  add	w.acc9, w.c, w.m2    ; Add dest value
  add	w.acc10, w.acc9, w.k3    ; Add constant 0x242070db
  add	w.acc11, w.acc10, w.f9    ; Add aux function result
  ror	w.acc12, w.acc11, #15    ; Rotate left s=17 bits
  eor	x.f10, x.d1, x.a1    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.c1, w.d1, w.acc12    ; Add X parameter round 1 C=FF(C, D, A, B, 0x242070db, s=17, M[2])
  and	x.f11, x.f10, x.c1    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f12, x.f11, x.a1    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k4, #0xceee    ; Load lower half of constant 0xc1bdceee
  movk	x.k4, #0xc1bd, lsl #16    ; Load upper half of constant 0xc1bdceee
  add	w.acc13, w.b, w.m3    ; Add dest value
  add	w.acc14, w.acc13, w.k4    ; Add constant 0xc1bdceee
  add	w.acc15, w.acc14, w.f12    ; Add aux function result
  ror	w.acc16, w.acc15, #10    ; Rotate left s=22 bits
  eor	x.f13, x.c1, x.d1    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.b1, w.c1, w.acc16    ; Add X parameter round 1 B=FF(B, C, D, A, 0xc1bdceee, s=22, M[3])
  ldp	w.m4, w.m5, [x.data, #16]    ; Load 2 words of input data0 M[4],M[5]
  ldp	w.m6, w.m7, [x.data, #24]    ; Load 2 words of input data0 M[6],M[7]
  and	x.f14, x.f13, x.b1    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f15, x.f14, x.d1    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k5, #0xfaf    ; Load lower half of constant 0xf57c0faf
  movk	x.k5, #0xf57c, lsl #16    ; Load upper half of constant 0xf57c0faf
  add	w.acc17, w.a1, w.m4    ; Add dest value
  add	w.acc18, w.acc17, w.k5    ; Add constant 0xf57c0faf
  add	w.acc19, w.acc18, w.f15    ; Add aux function result
  ror	w.acc20, w.acc19, #25    ; Rotate left s=7 bits
  eor	x.f16, x.b1, x.c1    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.a2, w.b1, w.acc20    ; Add X parameter round 1 A=FF(A, B, C, D, 0xf57c0faf, s=7, M[4])
  and	x.f17, x.f16, x.a2    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f18, x.f17, x.c1    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k6, #0xc62a    ; Load lower half of constant 0x4787c62a
  movk	x.k6, #0x4787, lsl #16    ; Load upper half of constant 0x4787c62a
  add	w.acc21, w.d1, w.m5    ; Add dest value
  add	w.acc22, w.acc21, w.k6    ; Add constant 0x4787c62a
  add	w.acc23, w.acc22, w.f18    ; Add aux function result
  ror	w.acc24, w.acc23, #20    ; Rotate left s=12 bits
  eor	x.f19, x.a2, x.b1    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.d2, w.a2, w.acc24    ; Add X parameter round 1 D=FF(D, A, B, C, 0x4787c62a, s=12, M[5])
  and	x.f20, x.f19, x.d2    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f21, x.f20, x.b1    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k7, #0x4613    ; Load lower half of constant 0xa8304613
  movk	x.k7, #0xa830, lsl #16    ; Load upper half of constant 0xa8304613
  add	w.acc25, w.c1, w.m6    ; Add dest value
  add	w.acc26, w.acc25, w.k7    ; Add constant 0xa8304613
  add	w.acc27, w.acc26, w.f21    ; Add aux function result
  ror	w.acc28, w.acc27, #15    ; Rotate left s=17 bits
  eor	x.f22, x.d2, x.a2    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.c2, w.d2, w.acc28    ; Add X parameter round 1 C=FF(C, D, A, B, 0xa8304613, s=17, M[6])
  and	x.f23, x.f22, x.c2    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f24, x.f23, x.a2    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k8, #0x9501    ; Load lower half of constant 0xfd469501
  movk	x.k8, #0xfd46, lsl #16    ; Load upper half of constant 0xfd469501
  add	w.acc29, w.b1, w.m7    ; Add dest value
  add	w.acc30, w.acc29, w.k8    ; Add constant 0xfd469501
  add	w.acc31, w.acc30, w.f24    ; Add aux function result
  ror	w.acc32, w.acc31, #10    ; Rotate left s=22 bits
  eor	x.f25, x.c2, x.d2    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.b2, w.c2, w.acc32    ; Add X parameter round 1 B=FF(B, C, D, A, 0xfd469501, s=22, M[7])
  ldp	w.m8, w.m9, [x.data, #32]    ; Load 2 words of input data0 M[8],M[9]
  ldp	w.m10, w.m11, [x.data, #40]    ; Load 2 words of input data0 M[10],M[11]
  and	x.f26, x.f25, x.b2    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f27, x.f26, x.d2    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k9, #0x98d8    ; Load lower half of constant 0x698098d8
  movk	x.k9, #0x6980, lsl #16    ; Load upper half of constant 0x698098d8
  add	w.acc33, w.a2, w.m8    ; Add dest value
  add	w.acc34, w.acc33, w.k9    ; Add constant 0x698098d8
  add	w.acc35, w.acc34, w.f27    ; Add aux function result
  ror	w.acc36, w.acc35, #25    ; Rotate left s=7 bits
  eor	x.f28, x.b2, x.c2    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.a3, w.b2, w.acc36    ; Add X parameter round 1 A=FF(A, B, C, D, 0x698098d8, s=7, M[8])
  and	x.f29, x.f28, x.a3    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f30, x.f29, x.c2    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k10, #0xf7af    ; Load lower half of constant 0x8b44f7af
  movk	x.k10, #0x8b44, lsl #16    ; Load upper half of constant 0x8b44f7af
  add	w.acc37, w.d2, w.m9    ; Add dest value
  add	w.acc38, w.acc37, w.k10    ; Add constant 0x8b44f7af
  add	w.acc39, w.acc38, w.f30    ; Add aux function result
  ror	w.acc40, w.acc39, #20    ; Rotate left s=12 bits
  eor	x.f31, x.a3, x.b2    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.d3, w.a3, w.acc40    ; Add X parameter round 1 D=FF(D, A, B, C, 0x8b44f7af, s=12, M[9])
  and	x.f32, x.f31, x.d3    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f33, x.f32, x.b2    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k11, #0x5bb1    ; Load lower half of constant 0xffff5bb1
  movk	x.k11, #0xffff, lsl #16    ; Load upper half of constant 0xffff5bb1
  add	w.acc41, w.c2, w.m10    ; Add dest value
  add	w.acc42, w.acc41, w.k11    ; Add constant 0xffff5bb1
  add	w.acc43, w.acc42, w.f33    ; Add aux function result
  ror	w.acc44, w.acc43, #15    ; Rotate left s=17 bits
  eor	x.f34, x.d3, x.a3    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.c3, w.d3, w.acc44    ; Add X parameter round 1 C=FF(C, D, A, B, 0xffff5bb1, s=17, M[10])
  and	x.f35, x.f34, x.c3    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f36, x.f35, x.a3    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k12, #0xd7be    ; Load lower half of constant 0x895cd7be
  movk	x.k12, #0x895c, lsl #16    ; Load upper half of constant 0x895cd7be
  add	w.acc45, w.b2, w.m11    ; Add dest value
  add	w.acc46, w.acc45, w.k12    ; Add constant 0x895cd7be
  add	w.acc47, w.acc46, w.f36    ; Add aux function result
  ror	w.acc48, w.acc47, #10    ; Rotate left s=22 bits
  eor	x.f37, x.c3, x.d3    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.b3, w.c3, w.acc48    ; Add X parameter round 1 B=FF(B, C, D, A, 0x895cd7be, s=22, M[11])
  ldp	w.m12, w.m13, [x.data, #48]    ; Load 2 words of input data0 M[12],M[13]
  ldp	w.m14, w.m15, [x.data, #56]    ; Load 2 words of input data0 M[14],M[15]
  and	x.f38, x.f37, x.b3    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f39, x.f38, x.d3    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k13, #0x1122    ; Load lower half of constant 0x6b901122
  movk	x.k13, #0x6b90, lsl #16    ; Load upper half of constant 0x6b901122
  add	w.acc49, w.a3, w.m12    ; Add dest value
  add	w.acc50, w.acc49, w.k13    ; Add constant 0x6b901122
  add	w.acc51, w.acc50, w.f39    ; Add aux function result
  ror	w.acc52, w.acc51, #25    ; Rotate left s=7 bits
  eor	x.f40, x.b3, x.c3    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.a4, w.b3, w.acc52    ; Add X parameter round 1 A=FF(A, B, C, D, 0x6b901122, s=7, M[12])
  and	x.f41, x.f40, x.a4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f42, x.f41, x.c3    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k14, #0x7193    ; Load lower half of constant 0xfd987193
  movk	x.k14, #0xfd98, lsl #16    ; Load upper half of constant 0xfd987193
  add	w.acc53, w.d3, w.m13    ; Add dest value
  add	w.acc54, w.acc53, w.k14    ; Add constant 0xfd987193
  add	w.acc55, w.acc54, w.f42    ; Add aux function result
  ror	w.acc56, w.acc55, #20    ; Rotate left s=12 bits
  eor	x.f43, x.a4, x.b3    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.d4, w.a4, w.acc56    ; Add X parameter round 1 D=FF(D, A, B, C, 0xfd987193, s=12, M[13])
  and	x.f44, x.f43, x.d4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f45, x.f44, x.b3    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k15, #0x438e    ; Load lower half of constant 0xa679438e
  movk	x.k15, #0xa679, lsl #16    ; Load upper half of constant 0xa679438e
  add	w.acc57, w.c3, w.m14    ; Add dest value
  add	w.acc58, w.acc57, w.k15    ; Add constant 0xa679438e
  add	w.acc59, w.acc58, w.f45    ; Add aux function result
  ror	w.acc60, w.acc59, #15    ; Rotate left s=17 bits
  eor	x.f46, x.d4, x.a4    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.c4, w.d4, w.acc60    ; Add X parameter round 1 C=FF(C, D, A, B, 0xa679438e, s=17, M[14])
  and	x.f47, x.f46, x.c4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.f48, x.f47, x.a4    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.k16, #0x821    ; Load lower half of constant 0x49b40821
  movk	x.k16, #0x49b4, lsl #16    ; Load upper half of constant 0x49b40821
  add	w.acc61, w.b3, w.m15    ; Add dest value
  add	w.acc62, w.acc61, w.k16    ; Add constant 0x49b40821
  add	w.acc63, w.acc62, w.f48    ; Add aux function result
  ror	w.acc64, w.acc63, #10    ; Rotate left s=22 bits
  bic	x.f49, x.c4, x.d4    ; Aux function round 2 (~z & y)
  add	w.b4, w.c4, w.acc64    ; Add X parameter round 1 B=FF(B, C, D, A, 0x49b40821, s=22, M[15])
  movz	x.k17, #0x2562    ; Load lower half of constant 0xf61e2562
  movk	x.k17, #0xf61e, lsl #16    ; Load upper half of constant 0xf61e2562
  add	w.acc65, w.a4, w.m1    ; Add dest value
  add	w.acc66, w.acc65, w.k17    ; Add constant 0xf61e2562
  and	x.f50, x.b4, x.d4    ; Aux function round 2 (x & z)
  add	w.acc67, w.acc66, w.f49    ; Add (~z & y)
  add	w.acc68, w.acc67, w.f50    ; Add (x & z)
  ror	w.acc69, w.acc68, #27    ; Rotate left s=5 bits
  bic	x.f51, x.b4, x.c4    ; Aux function round 2 (~z & y)
  add	w.a5, w.b4, w.acc69    ; Add X parameter round 2 A=GG(A, B, C, D, 0xf61e2562, s=5, M[1])
  movz	x.k18, #0xb340    ; Load lower half of constant 0xc040b340
  movk	x.k18, #0xc040, lsl #16    ; Load upper half of constant 0xc040b340
  add	w.acc70, w.d4, w.m6    ; Add dest value
  add	w.acc71, w.acc70, w.k18    ; Add constant 0xc040b340
  and	x.f52, x.a5, x.c4    ; Aux function round 2 (x & z)
  add	w.acc72, w.acc71, w.f51    ; Add (~z & y)
  add	w.acc73, w.acc72, w.f52    ; Add (x & z)
  ror	w.acc74, w.acc73, #23    ; Rotate left s=9 bits
  bic	x.f53, x.a5, x.b4    ; Aux function round 2 (~z & y)
  add	w.d5, w.a5, w.acc74    ; Add X parameter round 2 D=GG(D, A, B, C, 0xc040b340, s=9, M[6])
  movz	x.k19, #0x5a51    ; Load lower half of constant 0x265e5a51
  movk	x.k19, #0x265e, lsl #16    ; Load upper half of constant 0x265e5a51
  add	w.acc75, w.c4, w.m11    ; Add dest value
  add	w.acc76, w.acc75, w.k19    ; Add constant 0x265e5a51
  and	x.f54, x.d5, x.b4    ; Aux function round 2 (x & z)
  add	w.acc77, w.acc76, w.f53    ; Add (~z & y)
  add	w.acc78, w.acc77, w.f54    ; Add (x & z)
  ror	w.acc79, w.acc78, #18    ; Rotate left s=14 bits
  bic	x.f55, x.d5, x.a5    ; Aux function round 2 (~z & y)
  add	w.c5, w.d5, w.acc79    ; Add X parameter round 2 C=GG(C, D, A, B, 0x265e5a51, s=14, M[11])
  movz	x.k20, #0xc7aa    ; Load lower half of constant 0xe9b6c7aa
  movk	x.k20, #0xe9b6, lsl #16    ; Load upper half of constant 0xe9b6c7aa
  add	w.acc80, w.b4, w.m0    ; Add dest value
  add	w.acc81, w.acc80, w.k20    ; Add constant 0xe9b6c7aa
  and	x.f56, x.c5, x.a5    ; Aux function round 2 (x & z)
  add	w.acc82, w.acc81, w.f55    ; Add (~z & y)
  add	w.acc83, w.acc82, w.f56    ; Add (x & z)
  ror	w.acc84, w.acc83, #12    ; Rotate left s=20 bits
  bic	x.f57, x.c5, x.d5    ; Aux function round 2 (~z & y)
  add	w.b5, w.c5, w.acc84    ; Add X parameter round 2 B=GG(B, C, D, A, 0xe9b6c7aa, s=20, M[0])
  movz	x.k21, #0x105d    ; Load lower half of constant 0xd62f105d
  movk	x.k21, #0xd62f, lsl #16    ; Load upper half of constant 0xd62f105d
  add	w.acc85, w.a5, w.m5    ; Add dest value
  add	w.acc86, w.acc85, w.k21    ; Add constant 0xd62f105d
  and	x.f58, x.b5, x.d5    ; Aux function round 2 (x & z)
  add	w.acc87, w.acc86, w.f57    ; Add (~z & y)
  add	w.acc88, w.acc87, w.f58    ; Add (x & z)
  ror	w.acc89, w.acc88, #27    ; Rotate left s=5 bits
  bic	x.f59, x.b5, x.c5    ; Aux function round 2 (~z & y)
  add	w.a6, w.b5, w.acc89    ; Add X parameter round 2 A=GG(A, B, C, D, 0xd62f105d, s=5, M[5])
  movz	x.k22, #0x1453    ; Load lower half of constant 0x2441453
  movk	x.k22, #0x244, lsl #16    ; Load upper half of constant 0x2441453
  add	w.acc90, w.d5, w.m10    ; Add dest value
  add	w.acc91, w.acc90, w.k22    ; Add constant 0x2441453
  and	x.f60, x.a6, x.c5    ; Aux function round 2 (x & z)
  add	w.acc92, w.acc91, w.f59    ; Add (~z & y)
  add	w.acc93, w.acc92, w.f60    ; Add (x & z)
  ror	w.acc94, w.acc93, #23    ; Rotate left s=9 bits
  bic	x.f61, x.a6, x.b5    ; Aux function round 2 (~z & y)
  add	w.d6, w.a6, w.acc94    ; Add X parameter round 2 D=GG(D, A, B, C, 0x2441453, s=9, M[10])
  movz	x.k23, #0xe681    ; Load lower half of constant 0xd8a1e681
  movk	x.k23, #0xd8a1, lsl #16    ; Load upper half of constant 0xd8a1e681
  add	w.acc95, w.c5, w.m15    ; Add dest value
  add	w.acc96, w.acc95, w.k23    ; Add constant 0xd8a1e681
  and	x.f62, x.d6, x.b5    ; Aux function round 2 (x & z)
  add	w.acc97, w.acc96, w.f61    ; Add (~z & y)
  add	w.acc98, w.acc97, w.f62    ; Add (x & z)
  ror	w.acc99, w.acc98, #18    ; Rotate left s=14 bits
  bic	x.f63, x.d6, x.a6    ; Aux function round 2 (~z & y)
  add	w.c6, w.d6, w.acc99    ; Add X parameter round 2 C=GG(C, D, A, B, 0xd8a1e681, s=14, M[15])
  movz	x.k24, #0xfbc8    ; Load lower half of constant 0xe7d3fbc8
  movk	x.k24, #0xe7d3, lsl #16    ; Load upper half of constant 0xe7d3fbc8
  add	w.acc100, w.b5, w.m4    ; Add dest value
  add	w.acc101, w.acc100, w.k24    ; Add constant 0xe7d3fbc8
  and	x.f64, x.c6, x.a6    ; Aux function round 2 (x & z)
  add	w.acc102, w.acc101, w.f63    ; Add (~z & y)
  add	w.acc103, w.acc102, w.f64    ; Add (x & z)
  ror	w.acc104, w.acc103, #12    ; Rotate left s=20 bits
  bic	x.f65, x.c6, x.d6    ; Aux function round 2 (~z & y)
  add	w.b6, w.c6, w.acc104    ; Add X parameter round 2 B=GG(B, C, D, A, 0xe7d3fbc8, s=20, M[4])
  movz	x.k25, #0xcde6    ; Load lower half of constant 0x21e1cde6
  movk	x.k25, #0x21e1, lsl #16    ; Load upper half of constant 0x21e1cde6
  add	w.acc105, w.a6, w.m9    ; Add dest value
  add	w.acc106, w.acc105, w.k25    ; Add constant 0x21e1cde6
  and	x.f66, x.b6, x.d6    ; Aux function round 2 (x & z)
  add	w.acc107, w.acc106, w.f65    ; Add (~z & y)
  add	w.acc108, w.acc107, w.f66    ; Add (x & z)
  ror	w.acc109, w.acc108, #27    ; Rotate left s=5 bits
  bic	x.f67, x.b6, x.c6    ; Aux function round 2 (~z & y)
  add	w.a7, w.b6, w.acc109    ; Add X parameter round 2 A=GG(A, B, C, D, 0x21e1cde6, s=5, M[9])
  movz	x.k26, #0x7d6    ; Load lower half of constant 0xc33707d6
  movk	x.k26, #0xc337, lsl #16    ; Load upper half of constant 0xc33707d6
  add	w.acc110, w.d6, w.m14    ; Add dest value
  add	w.acc111, w.acc110, w.k26    ; Add constant 0xc33707d6
  and	x.f68, x.a7, x.c6    ; Aux function round 2 (x & z)
  add	w.acc112, w.acc111, w.f67    ; Add (~z & y)
  add	w.acc113, w.acc112, w.f68    ; Add (x & z)
  ror	w.acc114, w.acc113, #23    ; Rotate left s=9 bits
  bic	x.f69, x.a7, x.b6    ; Aux function round 2 (~z & y)
  add	w.d7, w.a7, w.acc114    ; Add X parameter round 2 D=GG(D, A, B, C, 0xc33707d6, s=9, M[14])
  movz	x.k27, #0xd87    ; Load lower half of constant 0xf4d50d87
  movk	x.k27, #0xf4d5, lsl #16    ; Load upper half of constant 0xf4d50d87
  add	w.acc115, w.c6, w.m3    ; Add dest value
  add	w.acc116, w.acc115, w.k27    ; Add constant 0xf4d50d87
  and	x.f70, x.d7, x.b6    ; Aux function round 2 (x & z)
  add	w.acc117, w.acc116, w.f69    ; Add (~z & y)
  add	w.acc118, w.acc117, w.f70    ; Add (x & z)
  ror	w.acc119, w.acc118, #18    ; Rotate left s=14 bits
  bic	x.f71, x.d7, x.a7    ; Aux function round 2 (~z & y)
  add	w.c7, w.d7, w.acc119    ; Add X parameter round 2 C=GG(C, D, A, B, 0xf4d50d87, s=14, M[3])
  movz	x.k28, #0x14ed    ; Load lower half of constant 0x455a14ed
  movk	x.k28, #0x455a, lsl #16    ; Load upper half of constant 0x455a14ed
  add	w.acc120, w.b6, w.m8    ; Add dest value
  add	w.acc121, w.acc120, w.k28    ; Add constant 0x455a14ed
  and	x.f72, x.c7, x.a7    ; Aux function round 2 (x & z)
  add	w.acc122, w.acc121, w.f71    ; Add (~z & y)
  add	w.acc123, w.acc122, w.f72    ; Add (x & z)
  ror	w.acc124, w.acc123, #12    ; Rotate left s=20 bits
  bic	x.f73, x.c7, x.d7    ; Aux function round 2 (~z & y)
  add	w.b7, w.c7, w.acc124    ; Add X parameter round 2 B=GG(B, C, D, A, 0x455a14ed, s=20, M[8])
  movz	x.k29, #0xe905    ; Load lower half of constant 0xa9e3e905
  movk	x.k29, #0xa9e3, lsl #16    ; Load upper half of constant 0xa9e3e905
  add	w.acc125, w.a7, w.m13    ; Add dest value
  add	w.acc126, w.acc125, w.k29    ; Add constant 0xa9e3e905
  and	x.f74, x.b7, x.d7    ; Aux function round 2 (x & z)
  add	w.acc127, w.acc126, w.f73    ; Add (~z & y)
  add	w.acc128, w.acc127, w.f74    ; Add (x & z)
  ror	w.acc129, w.acc128, #27    ; Rotate left s=5 bits
  bic	x.f75, x.b7, x.c7    ; Aux function round 2 (~z & y)
  add	w.a8, w.b7, w.acc129    ; Add X parameter round 2 A=GG(A, B, C, D, 0xa9e3e905, s=5, M[13])
  movz	x.k30, #0xa3f8    ; Load lower half of constant 0xfcefa3f8
  movk	x.k30, #0xfcef, lsl #16    ; Load upper half of constant 0xfcefa3f8
  add	w.acc130, w.d7, w.m2    ; Add dest value
  add	w.acc131, w.acc130, w.k30    ; Add constant 0xfcefa3f8
  and	x.f76, x.a8, x.c7    ; Aux function round 2 (x & z)
  add	w.acc132, w.acc131, w.f75    ; Add (~z & y)
  add	w.acc133, w.acc132, w.f76    ; Add (x & z)
  ror	w.acc134, w.acc133, #23    ; Rotate left s=9 bits
  bic	x.f77, x.a8, x.b7    ; Aux function round 2 (~z & y)
  add	w.d8, w.a8, w.acc134    ; Add X parameter round 2 D=GG(D, A, B, C, 0xfcefa3f8, s=9, M[2])
  movz	x.k31, #0x2d9    ; Load lower half of constant 0x676f02d9
  movk	x.k31, #0x676f, lsl #16    ; Load upper half of constant 0x676f02d9
  add	w.acc135, w.c7, w.m7    ; Add dest value
  add	w.acc136, w.acc135, w.k31    ; Add constant 0x676f02d9
  and	x.f78, x.d8, x.b7    ; Aux function round 2 (x & z)
  add	w.acc137, w.acc136, w.f77    ; Add (~z & y)
  add	w.acc138, w.acc137, w.f78    ; Add (x & z)
  ror	w.acc139, w.acc138, #18    ; Rotate left s=14 bits
  bic	x.f79, x.d8, x.a8    ; Aux function round 2 (~z & y)
  add	w.c8, w.d8, w.acc139    ; Add X parameter round 2 C=GG(C, D, A, B, 0x676f02d9, s=14, M[7])
  movz	x.k32, #0x4c8a    ; Load lower half of constant 0x8d2a4c8a
  movk	x.k32, #0x8d2a, lsl #16    ; Load upper half of constant 0x8d2a4c8a
  add	w.acc140, w.b7, w.m12    ; Add dest value
  add	w.acc141, w.acc140, w.k32    ; Add constant 0x8d2a4c8a
  and	x.f80, x.c8, x.a8    ; Aux function round 2 (x & z)
  add	w.acc142, w.acc141, w.f79    ; Add (~z & y)
  add	w.acc143, w.acc142, w.f80    ; Add (x & z)
  eor	x.f81, x.c8, x.d8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc144, w.acc143, #12    ; Rotate left s=20 bits
  movz	x.k33, #0x3942    ; Load lower half of constant 0xfffa3942
  add	w.b8, w.c8, w.acc144    ; Add X parameter round 2 B=GG(B, C, D, A, 0x8d2a4c8a, s=20, M[12])
  movk	x.k33, #0xfffa, lsl #16    ; Load upper half of constant 0xfffa3942
  add	w.acc145, w.a8, w.m5    ; Add dest value
  eor	x.f82, x.f81, x.b8    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc146, w.acc145, w.k33    ; Add constant 0xfffa3942
  add	w.acc147, w.acc146, w.f82    ; Add aux function result
  ror	w.acc148, w.acc147, #28    ; Rotate left s=4 bits
  eor	x.f83, x.b8, x.c8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k34, #0xf681    ; Load lower half of constant 0x8771f681
  add	w.a9, w.b8, w.acc148    ; Add X parameter round 3 A=HH(A, B, C, D, 0xfffa3942, s=4, M[5])
  movk	x.k34, #0x8771, lsl #16    ; Load upper half of constant 0x8771f681
  add	w.acc149, w.d8, w.m8    ; Add dest value
  eor	x.f84, x.f83, x.a9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc150, w.acc149, w.k34    ; Add constant 0x8771f681
  add	w.acc151, w.acc150, w.f84    ; Add aux function result
  eor	x.f85, x.a9, x.b8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc152, w.acc151, #21    ; Rotate left s=11 bits
  movz	x.k35, #0x6122    ; Load lower half of constant 0x6d9d6122
  add	w.d9, w.a9, w.acc152    ; Add X parameter round 3 D=HH(D, A, B, C, 0x8771f681, s=11, M[8])
  movk	x.k35, #0x6d9d, lsl #16    ; Load upper half of constant 0x6d9d6122
  add	w.acc153, w.c8, w.m11    ; Add dest value
  eor	x.f86, x.f85, x.d9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc154, w.acc153, w.k35    ; Add constant 0x6d9d6122
  add	w.acc155, w.acc154, w.f86    ; Add aux function result
  ror	w.acc156, w.acc155, #16    ; Rotate left s=16 bits
  eor	x.f87, x.d9, x.a9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k36, #0x380c    ; Load lower half of constant 0xfde5380c
  add	w.c9, w.d9, w.acc156    ; Add X parameter round 3 C=HH(C, D, A, B, 0x6d9d6122, s=16, M[11])
  movk	x.k36, #0xfde5, lsl #16    ; Load upper half of constant 0xfde5380c
  add	w.acc157, w.b8, w.m14    ; Add dest value
  eor	x.f88, x.f87, x.c9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc158, w.acc157, w.k36    ; Add constant 0xfde5380c
  add	w.acc159, w.acc158, w.f88    ; Add aux function result
  eor	x.f89, x.c9, x.d9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc160, w.acc159, #9    ; Rotate left s=23 bits
  movz	x.k37, #0xea44    ; Load lower half of constant 0xa4beea44
  add	w.b9, w.c9, w.acc160    ; Add X parameter round 3 B=HH(B, C, D, A, 0xfde5380c, s=23, M[14])
  movk	x.k37, #0xa4be, lsl #16    ; Load upper half of constant 0xa4beea44
  add	w.acc161, w.a9, w.m1    ; Add dest value
  eor	x.f90, x.f89, x.b9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc162, w.acc161, w.k37    ; Add constant 0xa4beea44
  add	w.acc163, w.acc162, w.f90    ; Add aux function result
  ror	w.acc164, w.acc163, #28    ; Rotate left s=4 bits
  eor	x.f91, x.b9, x.c9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k38, #0xcfa9    ; Load lower half of constant 0x4bdecfa9
  add	w.a10, w.b9, w.acc164    ; Add X parameter round 3 A=HH(A, B, C, D, 0xa4beea44, s=4, M[1])
  movk	x.k38, #0x4bde, lsl #16    ; Load upper half of constant 0x4bdecfa9
  add	w.acc165, w.d9, w.m4    ; Add dest value
  eor	x.f92, x.f91, x.a10    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc166, w.acc165, w.k38    ; Add constant 0x4bdecfa9
  add	w.acc167, w.acc166, w.f92    ; Add aux function result
  eor	x.f93, x.a10, x.b9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc168, w.acc167, #21    ; Rotate left s=11 bits
  movz	x.k39, #0x4b60    ; Load lower half of constant 0xf6bb4b60
  add	w.d10, w.a10, w.acc168    ; Add X parameter round 3 D=HH(D, A, B, C, 0x4bdecfa9, s=11, M[4])
  movk	x.k39, #0xf6bb, lsl #16    ; Load upper half of constant 0xf6bb4b60
  add	w.acc169, w.c9, w.m7    ; Add dest value
  eor	x.f94, x.f93, x.d10    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc170, w.acc169, w.k39    ; Add constant 0xf6bb4b60
  add	w.acc171, w.acc170, w.f94    ; Add aux function result
  ror	w.acc172, w.acc171, #16    ; Rotate left s=16 bits
  eor	x.f95, x.d10, x.a10    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k40, #0xbc70    ; Load lower half of constant 0xbebfbc70
  add	w.c10, w.d10, w.acc172    ; Add X parameter round 3 C=HH(C, D, A, B, 0xf6bb4b60, s=16, M[7])
  movk	x.k40, #0xbebf, lsl #16    ; Load upper half of constant 0xbebfbc70
  add	w.acc173, w.b9, w.m10    ; Add dest value
  eor	x.f96, x.f95, x.c10    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc174, w.acc173, w.k40    ; Add constant 0xbebfbc70
  add	w.acc175, w.acc174, w.f96    ; Add aux function result
  eor	x.f97, x.c10, x.d10    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc176, w.acc175, #9    ; Rotate left s=23 bits
  movz	x.k41, #0x7ec6    ; Load lower half of constant 0x289b7ec6
  add	w.b10, w.c10, w.acc176    ; Add X parameter round 3 B=HH(B, C, D, A, 0xbebfbc70, s=23, M[10])
  movk	x.k41, #0x289b, lsl #16    ; Load upper half of constant 0x289b7ec6
  add	w.acc177, w.a10, w.m13    ; Add dest value
  eor	x.f98, x.f97, x.b10    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc178, w.acc177, w.k41    ; Add constant 0x289b7ec6
  add	w.acc179, w.acc178, w.f98    ; Add aux function result
  ror	w.acc180, w.acc179, #28    ; Rotate left s=4 bits
  eor	x.f99, x.b10, x.c10    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k42, #0x27fa    ; Load lower half of constant 0xeaa127fa
  add	w.a11, w.b10, w.acc180    ; Add X parameter round 3 A=HH(A, B, C, D, 0x289b7ec6, s=4, M[13])
  movk	x.k42, #0xeaa1, lsl #16    ; Load upper half of constant 0xeaa127fa
  add	w.acc181, w.d10, w.m0    ; Add dest value
  eor	x.f100, x.f99, x.a11    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc182, w.acc181, w.k42    ; Add constant 0xeaa127fa
  add	w.acc183, w.acc182, w.f100    ; Add aux function result
  eor	x.f101, x.a11, x.b10    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc184, w.acc183, #21    ; Rotate left s=11 bits
  movz	x.k43, #0x3085    ; Load lower half of constant 0xd4ef3085
  add	w.d11, w.a11, w.acc184    ; Add X parameter round 3 D=HH(D, A, B, C, 0xeaa127fa, s=11, M[0])
  movk	x.k43, #0xd4ef, lsl #16    ; Load upper half of constant 0xd4ef3085
  add	w.acc185, w.c10, w.m3    ; Add dest value
  eor	x.f102, x.f101, x.d11    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc186, w.acc185, w.k43    ; Add constant 0xd4ef3085
  add	w.acc187, w.acc186, w.f102    ; Add aux function result
  ror	w.acc188, w.acc187, #16    ; Rotate left s=16 bits
  eor	x.f103, x.d11, x.a11    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k44, #0x1d05    ; Load lower half of constant 0x4881d05
  add	w.c11, w.d11, w.acc188    ; Add X parameter round 3 C=HH(C, D, A, B, 0xd4ef3085, s=16, M[3])
  movk	x.k44, #0x488, lsl #16    ; Load upper half of constant 0x4881d05
  add	w.acc189, w.b10, w.m6    ; Add dest value
  eor	x.f104, x.f103, x.c11    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc190, w.acc189, w.k44    ; Add constant 0x4881d05
  add	w.acc191, w.acc190, w.f104    ; Add aux function result
  eor	x.f105, x.c11, x.d11    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc192, w.acc191, #9    ; Rotate left s=23 bits
  movz	x.k45, #0xd039    ; Load lower half of constant 0xd9d4d039
  add	w.b11, w.c11, w.acc192    ; Add X parameter round 3 B=HH(B, C, D, A, 0x4881d05, s=23, M[6])
  movk	x.k45, #0xd9d4, lsl #16    ; Load upper half of constant 0xd9d4d039
  add	w.acc193, w.a11, w.m9    ; Add dest value
  eor	x.f106, x.f105, x.b11    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc194, w.acc193, w.k45    ; Add constant 0xd9d4d039
  add	w.acc195, w.acc194, w.f106    ; Add aux function result
  ror	w.acc196, w.acc195, #28    ; Rotate left s=4 bits
  eor	x.f107, x.b11, x.c11    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k46, #0x99e5    ; Load lower half of constant 0xe6db99e5
  add	w.a12, w.b11, w.acc196    ; Add X parameter round 3 A=HH(A, B, C, D, 0xd9d4d039, s=4, M[9])
  movk	x.k46, #0xe6db, lsl #16    ; Load upper half of constant 0xe6db99e5
  add	w.acc197, w.d11, w.m12    ; Add dest value
  eor	x.f108, x.f107, x.a12    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc198, w.acc197, w.k46    ; Add constant 0xe6db99e5
  add	w.acc199, w.acc198, w.f108    ; Add aux function result
  eor	x.f109, x.a12, x.b11    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.acc200, w.acc199, #21    ; Rotate left s=11 bits
  movz	x.k47, #0x7cf8    ; Load lower half of constant 0x1fa27cf8
  add	w.d12, w.a12, w.acc200    ; Add X parameter round 3 D=HH(D, A, B, C, 0xe6db99e5, s=11, M[12])
  movk	x.k47, #0x1fa2, lsl #16    ; Load upper half of constant 0x1fa27cf8
  add	w.acc201, w.c11, w.m15    ; Add dest value
  eor	x.f110, x.f109, x.d12    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc202, w.acc201, w.k47    ; Add constant 0x1fa27cf8
  add	w.acc203, w.acc202, w.f110    ; Add aux function result
  ror	w.acc204, w.acc203, #16    ; Rotate left s=16 bits
  eor	x.f111, x.d12, x.a12    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.k48, #0x5665    ; Load lower half of constant 0xc4ac5665
  add	w.c12, w.d12, w.acc204    ; Add X parameter round 3 C=HH(C, D, A, B, 0x1fa27cf8, s=16, M[15])
  movk	x.k48, #0xc4ac, lsl #16    ; Load upper half of constant 0xc4ac5665
  add	w.acc205, w.b11, w.m2    ; Add dest value
  eor	x.f112, x.f111, x.c12    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.acc206, w.acc205, w.k48    ; Add constant 0xc4ac5665
  add	w.acc207, w.acc206, w.f112    ; Add aux function result
  ror	w.acc208, w.acc207, #9    ; Rotate left s=23 bits
  movz	x.k49, #0x2244    ; Load lower half of constant 0xf4292244
  movk	x.k49, #0xf429, lsl #16    ; Load upper half of constant 0xf4292244
  add	w.b12, w.c12, w.acc208    ; Add X parameter round 3 B=HH(B, C, D, A, 0xc4ac5665, s=23, M[2])
  add	w.acc209, w.a12, w.m0    ; Add dest value
  orn	x.f113, x.b12, x.d12    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc210, w.acc209, w.k49    ; Add constant 0xf4292244
  eor	x.f114, x.c12, x.f113    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc211, w.acc210, w.f114    ; Add aux function result
  ror	w.acc212, w.acc211, #26    ; Rotate left s=6 bits
  movz	x.k50, #0xff97    ; Load lower half of constant 0x432aff97
  movk	x.k50, #0x432a, lsl #16    ; Load upper half of constant 0x432aff97
  add	w.a13, w.b12, w.acc212    ; Add X parameter round 4 A=II(A, B, C, D, 0xf4292244, s=6, M[0])
  orn	x.f115, x.a13, x.c12    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc213, w.d12, w.m7    ; Add dest value
  eor	x.f116, x.b12, x.f115    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc214, w.acc213, w.k50    ; Add constant 0x432aff97
  add	w.acc215, w.acc214, w.f116    ; Add aux function result
  ror	w.acc216, w.acc215, #22    ; Rotate left s=10 bits
  movz	x.k51, #0x23a7    ; Load lower half of constant 0xab9423a7
  movk	x.k51, #0xab94, lsl #16    ; Load upper half of constant 0xab9423a7
  add	w.d13, w.a13, w.acc216    ; Add X parameter round 4 D=II(D, A, B, C, 0x432aff97, s=10, M[7])
  add	w.acc217, w.c12, w.m14    ; Add dest value
  orn	x.f117, x.d13, x.b12    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc218, w.acc217, w.k51    ; Add constant 0xab9423a7
  eor	x.f118, x.a13, x.f117    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc219, w.acc218, w.f118    ; Add aux function result
  ror	w.acc220, w.acc219, #17    ; Rotate left s=15 bits
  movz	x.k52, #0xa039    ; Load lower half of constant 0xfc93a039
  movk	x.k52, #0xfc93, lsl #16    ; Load upper half of constant 0xfc93a039
  add	w.c13, w.d13, w.acc220    ; Add X parameter round 4 C=II(C, D, A, B, 0xab9423a7, s=15, M[14])
  orn	x.f119, x.c13, x.a13    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc221, w.b12, w.m5    ; Add dest value
  eor	x.f120, x.d13, x.f119    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc222, w.acc221, w.k52    ; Add constant 0xfc93a039
  add	w.acc223, w.acc222, w.f120    ; Add aux function result
  ror	w.acc224, w.acc223, #11    ; Rotate left s=21 bits
  movz	x.k53, #0x59c3    ; Load lower half of constant 0x655b59c3
  movk	x.k53, #0x655b, lsl #16    ; Load upper half of constant 0x655b59c3
  add	w.b13, w.c13, w.acc224    ; Add X parameter round 4 B=II(B, C, D, A, 0xfc93a039, s=21, M[5])
  add	w.acc225, w.a13, w.m12    ; Add dest value
  orn	x.f121, x.b13, x.d13    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc226, w.acc225, w.k53    ; Add constant 0x655b59c3
  eor	x.f122, x.c13, x.f121    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc227, w.acc226, w.f122    ; Add aux function result
  ror	w.acc228, w.acc227, #26    ; Rotate left s=6 bits
  movz	x.k54, #0xcc92    ; Load lower half of constant 0x8f0ccc92
  movk	x.k54, #0x8f0c, lsl #16    ; Load upper half of constant 0x8f0ccc92
  add	w.a14, w.b13, w.acc228    ; Add X parameter round 4 A=II(A, B, C, D, 0x655b59c3, s=6, M[12])
  orn	x.f123, x.a14, x.c13    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc229, w.d13, w.m3    ; Add dest value
  eor	x.f124, x.b13, x.f123    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc230, w.acc229, w.k54    ; Add constant 0x8f0ccc92
  add	w.acc231, w.acc230, w.f124    ; Add aux function result
  ror	w.acc232, w.acc231, #22    ; Rotate left s=10 bits
  movz	x.k55, #0xf47d    ; Load lower half of constant 0xffeff47d
  movk	x.k55, #0xffef, lsl #16    ; Load upper half of constant 0xffeff47d
  add	w.d14, w.a14, w.acc232    ; Add X parameter round 4 D=II(D, A, B, C, 0x8f0ccc92, s=10, M[3])
  add	w.acc233, w.c13, w.m10    ; Add dest value
  orn	x.f125, x.d14, x.b13    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc234, w.acc233, w.k55    ; Add constant 0xffeff47d
  eor	x.f126, x.a14, x.f125    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc235, w.acc234, w.f126    ; Add aux function result
  ror	w.acc236, w.acc235, #17    ; Rotate left s=15 bits
  movz	x.k56, #0x5dd1    ; Load lower half of constant 0x85845dd1
  movk	x.k56, #0x8584, lsl #16    ; Load upper half of constant 0x85845dd1
  add	w.c14, w.d14, w.acc236    ; Add X parameter round 4 C=II(C, D, A, B, 0xffeff47d, s=15, M[10])
  orn	x.f127, x.c14, x.a14    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc237, w.b13, w.m1    ; Add dest value
  eor	x.f128, x.d14, x.f127    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc238, w.acc237, w.k56    ; Add constant 0x85845dd1
  add	w.acc239, w.acc238, w.f128    ; Add aux function result
  ror	w.acc240, w.acc239, #11    ; Rotate left s=21 bits
  movz	x.k57, #0x7e4f    ; Load lower half of constant 0x6fa87e4f
  movk	x.k57, #0x6fa8, lsl #16    ; Load upper half of constant 0x6fa87e4f
  add	w.b14, w.c14, w.acc240    ; Add X parameter round 4 B=II(B, C, D, A, 0x85845dd1, s=21, M[1])
  add	w.acc241, w.a14, w.m8    ; Add dest value
  orn	x.f129, x.b14, x.d14    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc242, w.acc241, w.k57    ; Add constant 0x6fa87e4f
  eor	x.f130, x.c14, x.f129    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc243, w.acc242, w.f130    ; Add aux function result
  ror	w.acc244, w.acc243, #26    ; Rotate left s=6 bits
  movz	x.k58, #0xe6e0    ; Load lower half of constant 0xfe2ce6e0
  movk	x.k58, #0xfe2c, lsl #16    ; Load upper half of constant 0xfe2ce6e0
  add	w.a15, w.b14, w.acc244    ; Add X parameter round 4 A=II(A, B, C, D, 0x6fa87e4f, s=6, M[8])
  orn	x.f131, x.a15, x.c14    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc245, w.d14, w.m15    ; Add dest value
  eor	x.f132, x.b14, x.f131    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc246, w.acc245, w.k58    ; Add constant 0xfe2ce6e0
  add	w.acc247, w.acc246, w.f132    ; Add aux function result
  ror	w.acc248, w.acc247, #22    ; Rotate left s=10 bits
  movz	x.k59, #0x4314    ; Load lower half of constant 0xa3014314
  movk	x.k59, #0xa301, lsl #16    ; Load upper half of constant 0xa3014314
  add	w.d15, w.a15, w.acc248    ; Add X parameter round 4 D=II(D, A, B, C, 0xfe2ce6e0, s=10, M[15])
  add	w.acc249, w.c14, w.m6    ; Add dest value
  orn	x.f133, x.d15, x.b14    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc250, w.acc249, w.k59    ; Add constant 0xa3014314
  eor	x.f134, x.a15, x.f133    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc251, w.acc250, w.f134    ; Add aux function result
  ror	w.acc252, w.acc251, #17    ; Rotate left s=15 bits
  movz	x.k60, #0x11a1    ; Load lower half of constant 0x4e0811a1
  movk	x.k60, #0x4e08, lsl #16    ; Load upper half of constant 0x4e0811a1
  add	w.c15, w.d15, w.acc252    ; Add X parameter round 4 C=II(C, D, A, B, 0xa3014314, s=15, M[6])
  orn	x.f135, x.c15, x.a15    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc253, w.b14, w.m13    ; Add dest value
  eor	x.f136, x.d15, x.f135    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc254, w.acc253, w.k60    ; Add constant 0x4e0811a1
  add	w.acc255, w.acc254, w.f136    ; Add aux function result
  ror	w.acc256, w.acc255, #11    ; Rotate left s=21 bits
  movz	x.k61, #0x7e82    ; Load lower half of constant 0xf7537e82
  movk	x.k61, #0xf753, lsl #16    ; Load upper half of constant 0xf7537e82
  add	w.b15, w.c15, w.acc256    ; Add X parameter round 4 B=II(B, C, D, A, 0x4e0811a1, s=21, M[13])
  add	w.acc257, w.a15, w.m4    ; Add dest value
  orn	x.f137, x.b15, x.d15    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc258, w.acc257, w.k61    ; Add constant 0xf7537e82
  eor	x.f138, x.c15, x.f137    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc259, w.acc258, w.f138    ; Add aux function result
  ror	w.acc260, w.acc259, #26    ; Rotate left s=6 bits
  movz	x.k62, #0xf235    ; Load lower half of constant 0xbd3af235
  movk	x.k62, #0xbd3a, lsl #16    ; Load upper half of constant 0xbd3af235
  add	w.a16, w.b15, w.acc260    ; Add X parameter round 4 A=II(A, B, C, D, 0xf7537e82, s=6, M[4])
  orn	x.f139, x.a16, x.c15    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc261, w.d15, w.m11    ; Add dest value
  eor	x.f140, x.b15, x.f139    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc262, w.acc261, w.k62    ; Add constant 0xbd3af235
  add	w.acc263, w.acc262, w.f140    ; Add aux function result
  ror	w.acc264, w.acc263, #22    ; Rotate left s=10 bits
  movz	x.k63, #0xd2bb    ; Load lower half of constant 0x2ad7d2bb
  movk	x.k63, #0x2ad7, lsl #16    ; Load upper half of constant 0x2ad7d2bb
  add	w.d16, w.a16, w.acc264    ; Add X parameter round 4 D=II(D, A, B, C, 0xbd3af235, s=10, M[11])
  add	w.acc265, w.c15, w.m2    ; Add dest value
  orn	x.f141, x.d16, x.b15    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc266, w.acc265, w.k63    ; Add constant 0x2ad7d2bb
  eor	x.f142, x.a16, x.f141    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc267, w.acc266, w.f142    ; Add aux function result
  ror	w.acc268, w.acc267, #17    ; Rotate left s=15 bits
  movz	x.k64, #0xd391    ; Load lower half of constant 0xeb86d391
  movk	x.k64, #0xeb86, lsl #16    ; Load upper half of constant 0xeb86d391
  add	w.c16, w.d16, w.acc268    ; Add X parameter round 4 C=II(C, D, A, B, 0x2ad7d2bb, s=15, M[2])
  orn	x.f143, x.c16, x.a16    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc269, w.b15, w.m9    ; Add dest value
  eor	x.f144, x.d16, x.f143    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.acc270, w.acc269, w.k64    ; Add constant 0xeb86d391
  add	w.acc271, w.acc270, w.f144    ; Add aux function result
  ror	w.acc272, w.acc271, #11    ; Rotate left s=21 bits
  ldp	w.olda, w.oldb, [x.st]    ; Reload MD5 state->A and state->B
  ldp	w.oldc, w.oldd, [x.st, #8]    ; Reload MD5 state->C and state->D
  add	w.b16, w.c16, w.acc272    ; Add X parameter round 4 B=II(B, C, D, A, 0xeb86d391, s=21, M[9])
  add	w.d, w.d16, w.oldd    ; Add result of MD5 rounds to state->D
  add	w.c, w.c16, w.oldc    ; Add result of MD5 rounds to state->C
  add	w.a, w.a16, w.olda    ; Add result of MD5 rounds to state->A
  add	w.b, w.b16, w.oldb    ; Add result of MD5 rounds to state->B
  stp	w.c, w.d, [x.st, #8]    ; Store MD5 states C,D
  stp	w.a, w.b, [x.st]    ; Store MD5 states A,B
  add	x.data, x.data, #64    ; Increment data pointer
  subs	w.num, w.num, #1    ; Decrement block counter
  b.ne	loop
  .restore all
  ret
.end
