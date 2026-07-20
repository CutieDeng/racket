.function md5_blocks_asm export (
  in: x.st, x.data, x.num
)
entry:
  .save all
  ldp	w.r10, w.r11, [x.st, #0]    ; Load MD5 state->A and state->B
  ldp	w.r12, w.r13, [x.st, #8]    ; Load MD5 state->C and state->D
loop:
  eor	x.r17, x.r12, x.r13    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  and	x.r16, x.r17, x.r11    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  ldp	w.r15, w.r20, [x.data]    ; Load 2 words of input data0 M[0],M[1]
  ldp	w.r3, w.r21, [x.data, #8]    ; Load 2 words of input data0 M[2],M[3]
  eor	x.r14, x.r16, x.r13    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r9, #0xa478    ; Load lower half of constant 0xd76aa478
  movk	x.r9, #0xd76a, lsl #16    ; Load upper half of constant 0xd76aa478
  add	w.r8, w.r10, w.r15    ; Add dest value
  add	w.r7, w.r8, w.r9    ; Add constant 0xd76aa478
  add	w.r6, w.r7, w.r14    ; Add aux function result
  ror	w.r6, w.r6, #25    ; Rotate left s=7 bits
  eor	x.r5, x.r11, x.r12    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r4, w.r11, w.r6    ; Add X parameter round 1 A=FF(A, B, C, D, 0xd76aa478, s=7, M[0])
  and	x.r8, x.r5, x.r4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r17, x.r8, x.r12    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r16, #0xb756    ; Load lower half of constant 0xe8c7b756
  movk	x.r16, #0xe8c7, lsl #16    ; Load upper half of constant 0xe8c7b756
  add	w.r9, w.r13, w.r20    ; Add dest value
  add	w.r7, w.r9, w.r16    ; Add constant 0xe8c7b756
  add	w.r14, w.r7, w.r17    ; Add aux function result
  ror	w.r14, w.r14, #20    ; Rotate left s=12 bits
  eor	x.r6, x.r4, x.r11    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r5, w.r4, w.r14    ; Add X parameter round 1 D=FF(D, A, B, C, 0xe8c7b756, s=12, M[1])
  and	x.r8, x.r6, x.r5    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r9, x.r8, x.r11    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r16, #0x70db    ; Load lower half of constant 0x242070db
  movk	x.r16, #0x2420, lsl #16    ; Load upper half of constant 0x242070db
  add	w.r7, w.r12, w.r3    ; Add dest value
  add	w.r17, w.r7, w.r16    ; Add constant 0x242070db
  add	w.r14, w.r17, w.r9    ; Add aux function result
  ror	w.r14, w.r14, #15    ; Rotate left s=17 bits
  eor	x.r6, x.r5, x.r4    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r8, w.r5, w.r14    ; Add X parameter round 1 C=FF(C, D, A, B, 0x242070db, s=17, M[2])
  and	x.r7, x.r6, x.r8    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r16, x.r7, x.r4    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r9, #0xceee    ; Load lower half of constant 0xc1bdceee
  movk	x.r9, #0xc1bd, lsl #16    ; Load upper half of constant 0xc1bdceee
  add	w.r14, w.r11, w.r21    ; Add dest value
  add	w.r6, w.r14, w.r9    ; Add constant 0xc1bdceee
  add	w.r7, w.r6, w.r16    ; Add aux function result
  ror	w.r7, w.r7, #10    ; Rotate left s=22 bits
  eor	x.r17, x.r8, x.r5    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r9, w.r8, w.r7    ; Add X parameter round 1 B=FF(B, C, D, A, 0xc1bdceee, s=22, M[3])
  ldp	w.r14, w.r22, [x.data, #16]    ; Load 2 words of input data0 M[4],M[5]
  ldp	w.r7, w.r23, [x.data, #24]    ; Load 2 words of input data0 M[6],M[7]
  and	x.r16, x.r17, x.r9    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r16, x.r5    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r16, #0xfaf    ; Load lower half of constant 0xf57c0faf
  movk	x.r16, #0xf57c, lsl #16    ; Load upper half of constant 0xf57c0faf
  add	w.r17, w.r4, w.r14    ; Add dest value
  add	w.r16, w.r17, w.r16    ; Add constant 0xf57c0faf
  add	w.r4, w.r16, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #25    ; Rotate left s=7 bits
  eor	x.r16, x.r9, x.r8    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r17, w.r9, w.r4    ; Add X parameter round 1 A=FF(A, B, C, D, 0xf57c0faf, s=7, M[4])
  and	x.r16, x.r16, x.r17    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r16, x.r8    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r4, #0xc62a    ; Load lower half of constant 0x4787c62a
  movk	x.r4, #0x4787, lsl #16    ; Load upper half of constant 0x4787c62a
  add	w.r16, w.r5, w.r22    ; Add dest value
  add	w.r16, w.r16, w.r4    ; Add constant 0x4787c62a
  add	w.r5, w.r16, w.r6    ; Add aux function result
  ror	w.r5, w.r5, #20    ; Rotate left s=12 bits
  eor	x.r4, x.r17, x.r9    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r19, w.r17, w.r5    ; Add X parameter round 1 D=FF(D, A, B, C, 0x4787c62a, s=12, M[5])
  and	x.r6, x.r4, x.r19    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r5, x.r6, x.r9    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r4, #0x4613    ; Load lower half of constant 0xa8304613
  movk	x.r4, #0xa830, lsl #16    ; Load upper half of constant 0xa8304613
  add	w.r6, w.r8, w.r7    ; Add dest value
  add	w.r8, w.r6, w.r4    ; Add constant 0xa8304613
  add	w.r4, w.r8, w.r5    ; Add aux function result
  ror	w.r4, w.r4, #15    ; Rotate left s=17 bits
  eor	x.r6, x.r19, x.r17    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r8, w.r19, w.r4    ; Add X parameter round 1 C=FF(C, D, A, B, 0xa8304613, s=17, M[6])
  and	x.r5, x.r6, x.r8    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r4, x.r5, x.r17    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r6, #0x9501    ; Load lower half of constant 0xfd469501
  movk	x.r6, #0xfd46, lsl #16    ; Load upper half of constant 0xfd469501
  add	w.r9, w.r9, w.r23    ; Add dest value
  add	w.r5, w.r9, w.r6    ; Add constant 0xfd469501
  add	w.r9, w.r5, w.r4    ; Add aux function result
  ror	w.r9, w.r9, #10    ; Rotate left s=22 bits
  eor	x.r6, x.r8, x.r19    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r4, w.r8, w.r9    ; Add X parameter round 1 B=FF(B, C, D, A, 0xfd469501, s=22, M[7])
  ldp	w.r5, w.r24, [x.data, #32]    ; Load 2 words of input data0 M[8],M[9]
  ldp	w.r16, w.r25, [x.data, #40]    ; Load 2 words of input data0 M[10],M[11]
  and	x.r9, x.r6, x.r4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r9, x.r19    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r9, #0x98d8    ; Load lower half of constant 0x698098d8
  movk	x.r9, #0x6980, lsl #16    ; Load upper half of constant 0x698098d8
  add	w.r17, w.r17, w.r5    ; Add dest value
  add	w.r9, w.r17, w.r9    ; Add constant 0x698098d8
  add	w.r17, w.r9, w.r6    ; Add aux function result
  ror	w.r17, w.r17, #25    ; Rotate left s=7 bits
  eor	x.r9, x.r4, x.r8    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r6, w.r4, w.r17    ; Add X parameter round 1 A=FF(A, B, C, D, 0x698098d8, s=7, M[8])
  and	x.r17, x.r9, x.r6    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r9, x.r17, x.r8    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r17, #0xf7af    ; Load lower half of constant 0x8b44f7af
  movk	x.r17, #0x8b44, lsl #16    ; Load upper half of constant 0x8b44f7af
  add	w.r19, w.r19, w.r24    ; Add dest value
  add	w.r17, w.r19, w.r17    ; Add constant 0x8b44f7af
  add	w.r19, w.r17, w.r9    ; Add aux function result
  ror	w.r19, w.r19, #20    ; Rotate left s=12 bits
  eor	x.r9, x.r6, x.r4    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r17, w.r6, w.r19    ; Add X parameter round 1 D=FF(D, A, B, C, 0x8b44f7af, s=12, M[9])
  and	x.r9, x.r9, x.r17    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r9, x.r9, x.r4    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r11, #0x5bb1    ; Load lower half of constant 0xffff5bb1
  movk	x.r11, #0xffff, lsl #16    ; Load upper half of constant 0xffff5bb1
  add	w.r8, w.r8, w.r16    ; Add dest value
  add	w.r8, w.r8, w.r11    ; Add constant 0xffff5bb1
  add	w.r8, w.r8, w.r9    ; Add aux function result
  ror	w.r8, w.r8, #15    ; Rotate left s=17 bits
  eor	x.r9, x.r17, x.r6    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 1 C=FF(C, D, A, B, 0xffff5bb1, s=17, M[10])
  and	x.r9, x.r9, x.r8    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r9, x.r9, x.r6    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r11, #0xd7be    ; Load lower half of constant 0x895cd7be
  movk	x.r11, #0x895c, lsl #16    ; Load upper half of constant 0x895cd7be
  add	w.r4, w.r4, w.r25    ; Add dest value
  add	w.r4, w.r4, w.r11    ; Add constant 0x895cd7be
  add	w.r9, w.r4, w.r9    ; Add aux function result
  ror	w.r9, w.r9, #10    ; Rotate left s=22 bits
  eor	x.r4, x.r8, x.r17    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r9, w.r8, w.r9    ; Add X parameter round 1 B=FF(B, C, D, A, 0x895cd7be, s=22, M[11])
  ldp	w.r11, w.r26, [x.data, #48]    ; Load 2 words of input data0 M[12],M[13]
  ldp	w.r12, w.r27, [x.data, #56]    ; Load 2 words of input data0 M[14],M[15]
  and	x.r4, x.r4, x.r9    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r4, x.r4, x.r17    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r19, #0x1122    ; Load lower half of constant 0x6b901122
  movk	x.r19, #0x6b90, lsl #16    ; Load upper half of constant 0x6b901122
  add	w.r6, w.r6, w.r11    ; Add dest value
  add	w.r6, w.r6, w.r19    ; Add constant 0x6b901122
  add	w.r4, w.r6, w.r4    ; Add aux function result
  ror	w.r4, w.r4, #25    ; Rotate left s=7 bits
  eor	x.r6, x.r9, x.r8    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r4, w.r9, w.r4    ; Add X parameter round 1 A=FF(A, B, C, D, 0x6b901122, s=7, M[12])
  and	x.r6, x.r6, x.r4    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r6, x.r8    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r19, #0x7193    ; Load lower half of constant 0xfd987193
  movk	x.r19, #0xfd98, lsl #16    ; Load upper half of constant 0xfd987193
  add	w.r17, w.r17, w.r26    ; Add dest value
  add	w.r17, w.r17, w.r19    ; Add constant 0xfd987193
  add	w.r17, w.r17, w.r6    ; Add aux function result
  ror	w.r17, w.r17, #20    ; Rotate left s=12 bits
  eor	x.r6, x.r4, x.r9    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r17, w.r4, w.r17    ; Add X parameter round 1 D=FF(D, A, B, C, 0xfd987193, s=12, M[13])
  and	x.r6, x.r6, x.r17    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r6, x.r9    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r13, #0x438e    ; Load lower half of constant 0xa679438e
  movk	x.r13, #0xa679, lsl #16    ; Load upper half of constant 0xa679438e
  add	w.r8, w.r8, w.r12    ; Add dest value
  add	w.r8, w.r8, w.r13    ; Add constant 0xa679438e
  add	w.r8, w.r8, w.r6    ; Add aux function result
  ror	w.r8, w.r8, #15    ; Rotate left s=17 bits
  eor	x.r6, x.r17, x.r4    ; Begin aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 1 C=FF(C, D, A, B, 0xa679438e, s=17, M[14])
  and	x.r6, x.r6, x.r8    ; Continue aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  eor	x.r6, x.r6, x.r4    ; End aux function round 1 F(x,y,z)=(((y^z)&x)^z)
  movz	x.r13, #0x821    ; Load lower half of constant 0x49b40821
  movk	x.r13, #0x49b4, lsl #16    ; Load upper half of constant 0x49b40821
  add	w.r9, w.r9, w.r27    ; Add dest value
  add	w.r9, w.r9, w.r13    ; Add constant 0x49b40821
  add	w.r9, w.r9, w.r6    ; Add aux function result
  ror	w.r9, w.r9, #10    ; Rotate left s=22 bits
  bic	x.r6, x.r8, x.r17    ; Aux function round 2 (~z & y)
  add	w.r9, w.r8, w.r9    ; Add X parameter round 1 B=FF(B, C, D, A, 0x49b40821, s=22, M[15])
  movz	x.r13, #0x2562    ; Load lower half of constant 0xf61e2562
  movk	x.r13, #0xf61e, lsl #16    ; Load upper half of constant 0xf61e2562
  add	w.r4, w.r4, w.r20    ; Add dest value
  add	w.r4, w.r4, w.r13    ; Add constant 0xf61e2562
  and	x.r13, x.r9, x.r17    ; Aux function round 2 (x & z)
  add	w.r4, w.r4, w.r6    ; Add (~z & y)
  add	w.r4, w.r4, w.r13    ; Add (x & z)
  ror	w.r4, w.r4, #27    ; Rotate left s=5 bits
  bic	x.r6, x.r9, x.r8    ; Aux function round 2 (~z & y)
  add	w.r4, w.r9, w.r4    ; Add X parameter round 2 A=GG(A, B, C, D, 0xf61e2562, s=5, M[1])
  movz	x.r13, #0xb340    ; Load lower half of constant 0xc040b340
  movk	x.r13, #0xc040, lsl #16    ; Load upper half of constant 0xc040b340
  add	w.r17, w.r17, w.r7    ; Add dest value
  add	w.r17, w.r17, w.r13    ; Add constant 0xc040b340
  and	x.r13, x.r4, x.r8    ; Aux function round 2 (x & z)
  add	w.r17, w.r17, w.r6    ; Add (~z & y)
  add	w.r17, w.r17, w.r13    ; Add (x & z)
  ror	w.r17, w.r17, #23    ; Rotate left s=9 bits
  bic	x.r6, x.r4, x.r9    ; Aux function round 2 (~z & y)
  add	w.r17, w.r4, w.r17    ; Add X parameter round 2 D=GG(D, A, B, C, 0xc040b340, s=9, M[6])
  movz	x.r13, #0x5a51    ; Load lower half of constant 0x265e5a51
  movk	x.r13, #0x265e, lsl #16    ; Load upper half of constant 0x265e5a51
  add	w.r8, w.r8, w.r25    ; Add dest value
  add	w.r8, w.r8, w.r13    ; Add constant 0x265e5a51
  and	x.r13, x.r17, x.r9    ; Aux function round 2 (x & z)
  add	w.r8, w.r8, w.r6    ; Add (~z & y)
  add	w.r8, w.r8, w.r13    ; Add (x & z)
  ror	w.r8, w.r8, #18    ; Rotate left s=14 bits
  bic	x.r6, x.r17, x.r4    ; Aux function round 2 (~z & y)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 2 C=GG(C, D, A, B, 0x265e5a51, s=14, M[11])
  movz	x.r13, #0xc7aa    ; Load lower half of constant 0xe9b6c7aa
  movk	x.r13, #0xe9b6, lsl #16    ; Load upper half of constant 0xe9b6c7aa
  add	w.r9, w.r9, w.r15    ; Add dest value
  add	w.r9, w.r9, w.r13    ; Add constant 0xe9b6c7aa
  and	x.r13, x.r8, x.r4    ; Aux function round 2 (x & z)
  add	w.r9, w.r9, w.r6    ; Add (~z & y)
  add	w.r9, w.r9, w.r13    ; Add (x & z)
  ror	w.r9, w.r9, #12    ; Rotate left s=20 bits
  bic	x.r6, x.r8, x.r17    ; Aux function round 2 (~z & y)
  add	w.r9, w.r8, w.r9    ; Add X parameter round 2 B=GG(B, C, D, A, 0xe9b6c7aa, s=20, M[0])
  movz	x.r13, #0x105d    ; Load lower half of constant 0xd62f105d
  movk	x.r13, #0xd62f, lsl #16    ; Load upper half of constant 0xd62f105d
  add	w.r4, w.r4, w.r22    ; Add dest value
  add	w.r4, w.r4, w.r13    ; Add constant 0xd62f105d
  and	x.r13, x.r9, x.r17    ; Aux function round 2 (x & z)
  add	w.r4, w.r4, w.r6    ; Add (~z & y)
  add	w.r4, w.r4, w.r13    ; Add (x & z)
  ror	w.r4, w.r4, #27    ; Rotate left s=5 bits
  bic	x.r6, x.r9, x.r8    ; Aux function round 2 (~z & y)
  add	w.r4, w.r9, w.r4    ; Add X parameter round 2 A=GG(A, B, C, D, 0xd62f105d, s=5, M[5])
  movz	x.r13, #0x1453    ; Load lower half of constant 0x2441453
  movk	x.r13, #0x244, lsl #16    ; Load upper half of constant 0x2441453
  add	w.r17, w.r17, w.r16    ; Add dest value
  add	w.r17, w.r17, w.r13    ; Add constant 0x2441453
  and	x.r13, x.r4, x.r8    ; Aux function round 2 (x & z)
  add	w.r17, w.r17, w.r6    ; Add (~z & y)
  add	w.r17, w.r17, w.r13    ; Add (x & z)
  ror	w.r17, w.r17, #23    ; Rotate left s=9 bits
  bic	x.r6, x.r4, x.r9    ; Aux function round 2 (~z & y)
  add	w.r17, w.r4, w.r17    ; Add X parameter round 2 D=GG(D, A, B, C, 0x2441453, s=9, M[10])
  movz	x.r13, #0xe681    ; Load lower half of constant 0xd8a1e681
  movk	x.r13, #0xd8a1, lsl #16    ; Load upper half of constant 0xd8a1e681
  add	w.r8, w.r8, w.r27    ; Add dest value
  add	w.r8, w.r8, w.r13    ; Add constant 0xd8a1e681
  and	x.r13, x.r17, x.r9    ; Aux function round 2 (x & z)
  add	w.r8, w.r8, w.r6    ; Add (~z & y)
  add	w.r8, w.r8, w.r13    ; Add (x & z)
  ror	w.r8, w.r8, #18    ; Rotate left s=14 bits
  bic	x.r6, x.r17, x.r4    ; Aux function round 2 (~z & y)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 2 C=GG(C, D, A, B, 0xd8a1e681, s=14, M[15])
  movz	x.r13, #0xfbc8    ; Load lower half of constant 0xe7d3fbc8
  movk	x.r13, #0xe7d3, lsl #16    ; Load upper half of constant 0xe7d3fbc8
  add	w.r9, w.r9, w.r14    ; Add dest value
  add	w.r9, w.r9, w.r13    ; Add constant 0xe7d3fbc8
  and	x.r13, x.r8, x.r4    ; Aux function round 2 (x & z)
  add	w.r9, w.r9, w.r6    ; Add (~z & y)
  add	w.r9, w.r9, w.r13    ; Add (x & z)
  ror	w.r9, w.r9, #12    ; Rotate left s=20 bits
  bic	x.r6, x.r8, x.r17    ; Aux function round 2 (~z & y)
  add	w.r9, w.r8, w.r9    ; Add X parameter round 2 B=GG(B, C, D, A, 0xe7d3fbc8, s=20, M[4])
  movz	x.r13, #0xcde6    ; Load lower half of constant 0x21e1cde6
  movk	x.r13, #0x21e1, lsl #16    ; Load upper half of constant 0x21e1cde6
  add	w.r4, w.r4, w.r24    ; Add dest value
  add	w.r4, w.r4, w.r13    ; Add constant 0x21e1cde6
  and	x.r13, x.r9, x.r17    ; Aux function round 2 (x & z)
  add	w.r4, w.r4, w.r6    ; Add (~z & y)
  add	w.r4, w.r4, w.r13    ; Add (x & z)
  ror	w.r4, w.r4, #27    ; Rotate left s=5 bits
  bic	x.r6, x.r9, x.r8    ; Aux function round 2 (~z & y)
  add	w.r4, w.r9, w.r4    ; Add X parameter round 2 A=GG(A, B, C, D, 0x21e1cde6, s=5, M[9])
  movz	x.r13, #0x7d6    ; Load lower half of constant 0xc33707d6
  movk	x.r13, #0xc337, lsl #16    ; Load upper half of constant 0xc33707d6
  add	w.r17, w.r17, w.r12    ; Add dest value
  add	w.r17, w.r17, w.r13    ; Add constant 0xc33707d6
  and	x.r13, x.r4, x.r8    ; Aux function round 2 (x & z)
  add	w.r17, w.r17, w.r6    ; Add (~z & y)
  add	w.r17, w.r17, w.r13    ; Add (x & z)
  ror	w.r17, w.r17, #23    ; Rotate left s=9 bits
  bic	x.r6, x.r4, x.r9    ; Aux function round 2 (~z & y)
  add	w.r17, w.r4, w.r17    ; Add X parameter round 2 D=GG(D, A, B, C, 0xc33707d6, s=9, M[14])
  movz	x.r13, #0xd87    ; Load lower half of constant 0xf4d50d87
  movk	x.r13, #0xf4d5, lsl #16    ; Load upper half of constant 0xf4d50d87
  add	w.r8, w.r8, w.r21    ; Add dest value
  add	w.r8, w.r8, w.r13    ; Add constant 0xf4d50d87
  and	x.r13, x.r17, x.r9    ; Aux function round 2 (x & z)
  add	w.r8, w.r8, w.r6    ; Add (~z & y)
  add	w.r8, w.r8, w.r13    ; Add (x & z)
  ror	w.r8, w.r8, #18    ; Rotate left s=14 bits
  bic	x.r6, x.r17, x.r4    ; Aux function round 2 (~z & y)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 2 C=GG(C, D, A, B, 0xf4d50d87, s=14, M[3])
  movz	x.r13, #0x14ed    ; Load lower half of constant 0x455a14ed
  movk	x.r13, #0x455a, lsl #16    ; Load upper half of constant 0x455a14ed
  add	w.r9, w.r9, w.r5    ; Add dest value
  add	w.r9, w.r9, w.r13    ; Add constant 0x455a14ed
  and	x.r13, x.r8, x.r4    ; Aux function round 2 (x & z)
  add	w.r9, w.r9, w.r6    ; Add (~z & y)
  add	w.r9, w.r9, w.r13    ; Add (x & z)
  ror	w.r9, w.r9, #12    ; Rotate left s=20 bits
  bic	x.r6, x.r8, x.r17    ; Aux function round 2 (~z & y)
  add	w.r9, w.r8, w.r9    ; Add X parameter round 2 B=GG(B, C, D, A, 0x455a14ed, s=20, M[8])
  movz	x.r13, #0xe905    ; Load lower half of constant 0xa9e3e905
  movk	x.r13, #0xa9e3, lsl #16    ; Load upper half of constant 0xa9e3e905
  add	w.r4, w.r4, w.r26    ; Add dest value
  add	w.r4, w.r4, w.r13    ; Add constant 0xa9e3e905
  and	x.r13, x.r9, x.r17    ; Aux function round 2 (x & z)
  add	w.r4, w.r4, w.r6    ; Add (~z & y)
  add	w.r4, w.r4, w.r13    ; Add (x & z)
  ror	w.r4, w.r4, #27    ; Rotate left s=5 bits
  bic	x.r6, x.r9, x.r8    ; Aux function round 2 (~z & y)
  add	w.r4, w.r9, w.r4    ; Add X parameter round 2 A=GG(A, B, C, D, 0xa9e3e905, s=5, M[13])
  movz	x.r13, #0xa3f8    ; Load lower half of constant 0xfcefa3f8
  movk	x.r13, #0xfcef, lsl #16    ; Load upper half of constant 0xfcefa3f8
  add	w.r17, w.r17, w.r3    ; Add dest value
  add	w.r17, w.r17, w.r13    ; Add constant 0xfcefa3f8
  and	x.r13, x.r4, x.r8    ; Aux function round 2 (x & z)
  add	w.r17, w.r17, w.r6    ; Add (~z & y)
  add	w.r17, w.r17, w.r13    ; Add (x & z)
  ror	w.r17, w.r17, #23    ; Rotate left s=9 bits
  bic	x.r6, x.r4, x.r9    ; Aux function round 2 (~z & y)
  add	w.r17, w.r4, w.r17    ; Add X parameter round 2 D=GG(D, A, B, C, 0xfcefa3f8, s=9, M[2])
  movz	x.r13, #0x2d9    ; Load lower half of constant 0x676f02d9
  movk	x.r13, #0x676f, lsl #16    ; Load upper half of constant 0x676f02d9
  add	w.r8, w.r8, w.r23    ; Add dest value
  add	w.r8, w.r8, w.r13    ; Add constant 0x676f02d9
  and	x.r13, x.r17, x.r9    ; Aux function round 2 (x & z)
  add	w.r8, w.r8, w.r6    ; Add (~z & y)
  add	w.r8, w.r8, w.r13    ; Add (x & z)
  ror	w.r8, w.r8, #18    ; Rotate left s=14 bits
  bic	x.r6, x.r17, x.r4    ; Aux function round 2 (~z & y)
  add	w.r8, w.r17, w.r8    ; Add X parameter round 2 C=GG(C, D, A, B, 0x676f02d9, s=14, M[7])
  movz	x.r13, #0x4c8a    ; Load lower half of constant 0x8d2a4c8a
  movk	x.r13, #0x8d2a, lsl #16    ; Load upper half of constant 0x8d2a4c8a
  add	w.r9, w.r9, w.r11    ; Add dest value
  add	w.r9, w.r9, w.r13    ; Add constant 0x8d2a4c8a
  and	x.r13, x.r8, x.r4    ; Aux function round 2 (x & z)
  add	w.r9, w.r9, w.r6    ; Add (~z & y)
  add	w.r9, w.r9, w.r13    ; Add (x & z)
  eor	x.r6, x.r8, x.r17    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r9, w.r9, #12    ; Rotate left s=20 bits
  movz	x.r10, #0x3942    ; Load lower half of constant 0xfffa3942
  add	w.r9, w.r8, w.r9    ; Add X parameter round 2 B=GG(B, C, D, A, 0x8d2a4c8a, s=20, M[12])
  movk	x.r10, #0xfffa, lsl #16    ; Load upper half of constant 0xfffa3942
  add	w.r4, w.r4, w.r22    ; Add dest value
  eor	x.r6, x.r6, x.r9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r4, w.r4, w.r10    ; Add constant 0xfffa3942
  add	w.r4, w.r4, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #28    ; Rotate left s=4 bits
  eor	x.r6, x.r9, x.r8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r10, #0xf681    ; Load lower half of constant 0x8771f681
  add	w.r4, w.r9, w.r4    ; Add X parameter round 3 A=HH(A, B, C, D, 0xfffa3942, s=4, M[5])
  movk	x.r10, #0x8771, lsl #16    ; Load upper half of constant 0x8771f681
  add	w.r17, w.r17, w.r5    ; Add dest value
  eor	x.r6, x.r6, x.r4    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r17, w.r17, w.r10    ; Add constant 0x8771f681
  add	w.r17, w.r17, w.r6    ; Add aux function result
  eor	x.r6, x.r4, x.r9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r17, w.r17, #21    ; Rotate left s=11 bits
  movz	x.r13, #0x6122    ; Load lower half of constant 0x6d9d6122
  add	w.r17, w.r4, w.r17    ; Add X parameter round 3 D=HH(D, A, B, C, 0x8771f681, s=11, M[8])
  movk	x.r13, #0x6d9d, lsl #16    ; Load upper half of constant 0x6d9d6122
  add	w.r8, w.r8, w.r25    ; Add dest value
  eor	x.r6, x.r6, x.r17    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r8, w.r8, w.r13    ; Add constant 0x6d9d6122
  add	w.r8, w.r8, w.r6    ; Add aux function result
  ror	w.r8, w.r8, #16    ; Rotate left s=16 bits
  eor	x.r6, x.r17, x.r4    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r13, #0x380c    ; Load lower half of constant 0xfde5380c
  add	w.r8, w.r17, w.r8    ; Add X parameter round 3 C=HH(C, D, A, B, 0x6d9d6122, s=16, M[11])
  movk	x.r13, #0xfde5, lsl #16    ; Load upper half of constant 0xfde5380c
  add	w.r9, w.r9, w.r12    ; Add dest value
  eor	x.r6, x.r6, x.r8    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r9, w.r9, w.r13    ; Add constant 0xfde5380c
  add	w.r9, w.r9, w.r6    ; Add aux function result
  eor	x.r6, x.r8, x.r17    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r9, w.r9, #9    ; Rotate left s=23 bits
  movz	x.r10, #0xea44    ; Load lower half of constant 0xa4beea44
  add	w.r9, w.r8, w.r9    ; Add X parameter round 3 B=HH(B, C, D, A, 0xfde5380c, s=23, M[14])
  movk	x.r10, #0xa4be, lsl #16    ; Load upper half of constant 0xa4beea44
  add	w.r4, w.r4, w.r20    ; Add dest value
  eor	x.r6, x.r6, x.r9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r4, w.r4, w.r10    ; Add constant 0xa4beea44
  add	w.r4, w.r4, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #28    ; Rotate left s=4 bits
  eor	x.r6, x.r9, x.r8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r10, #0xcfa9    ; Load lower half of constant 0x4bdecfa9
  add	w.r4, w.r9, w.r4    ; Add X parameter round 3 A=HH(A, B, C, D, 0xa4beea44, s=4, M[1])
  movk	x.r10, #0x4bde, lsl #16    ; Load upper half of constant 0x4bdecfa9
  add	w.r17, w.r17, w.r14    ; Add dest value
  eor	x.r6, x.r6, x.r4    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r17, w.r17, w.r10    ; Add constant 0x4bdecfa9
  add	w.r17, w.r17, w.r6    ; Add aux function result
  eor	x.r6, x.r4, x.r9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r17, w.r17, #21    ; Rotate left s=11 bits
  movz	x.r13, #0x4b60    ; Load lower half of constant 0xf6bb4b60
  add	w.r17, w.r4, w.r17    ; Add X parameter round 3 D=HH(D, A, B, C, 0x4bdecfa9, s=11, M[4])
  movk	x.r13, #0xf6bb, lsl #16    ; Load upper half of constant 0xf6bb4b60
  add	w.r8, w.r8, w.r23    ; Add dest value
  eor	x.r6, x.r6, x.r17    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r8, w.r8, w.r13    ; Add constant 0xf6bb4b60
  add	w.r8, w.r8, w.r6    ; Add aux function result
  ror	w.r8, w.r8, #16    ; Rotate left s=16 bits
  eor	x.r6, x.r17, x.r4    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r13, #0xbc70    ; Load lower half of constant 0xbebfbc70
  add	w.r8, w.r17, w.r8    ; Add X parameter round 3 C=HH(C, D, A, B, 0xf6bb4b60, s=16, M[7])
  movk	x.r13, #0xbebf, lsl #16    ; Load upper half of constant 0xbebfbc70
  add	w.r9, w.r9, w.r16    ; Add dest value
  eor	x.r6, x.r6, x.r8    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r9, w.r9, w.r13    ; Add constant 0xbebfbc70
  add	w.r9, w.r9, w.r6    ; Add aux function result
  eor	x.r6, x.r8, x.r17    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r9, w.r9, #9    ; Rotate left s=23 bits
  movz	x.r10, #0x7ec6    ; Load lower half of constant 0x289b7ec6
  add	w.r9, w.r8, w.r9    ; Add X parameter round 3 B=HH(B, C, D, A, 0xbebfbc70, s=23, M[10])
  movk	x.r10, #0x289b, lsl #16    ; Load upper half of constant 0x289b7ec6
  add	w.r4, w.r4, w.r26    ; Add dest value
  eor	x.r6, x.r6, x.r9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r4, w.r4, w.r10    ; Add constant 0x289b7ec6
  add	w.r4, w.r4, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #28    ; Rotate left s=4 bits
  eor	x.r6, x.r9, x.r8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r10, #0x27fa    ; Load lower half of constant 0xeaa127fa
  add	w.r4, w.r9, w.r4    ; Add X parameter round 3 A=HH(A, B, C, D, 0x289b7ec6, s=4, M[13])
  movk	x.r10, #0xeaa1, lsl #16    ; Load upper half of constant 0xeaa127fa
  add	w.r17, w.r17, w.r15    ; Add dest value
  eor	x.r6, x.r6, x.r4    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r17, w.r17, w.r10    ; Add constant 0xeaa127fa
  add	w.r17, w.r17, w.r6    ; Add aux function result
  eor	x.r6, x.r4, x.r9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r17, w.r17, #21    ; Rotate left s=11 bits
  movz	x.r13, #0x3085    ; Load lower half of constant 0xd4ef3085
  add	w.r17, w.r4, w.r17    ; Add X parameter round 3 D=HH(D, A, B, C, 0xeaa127fa, s=11, M[0])
  movk	x.r13, #0xd4ef, lsl #16    ; Load upper half of constant 0xd4ef3085
  add	w.r8, w.r8, w.r21    ; Add dest value
  eor	x.r6, x.r6, x.r17    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r8, w.r8, w.r13    ; Add constant 0xd4ef3085
  add	w.r8, w.r8, w.r6    ; Add aux function result
  ror	w.r8, w.r8, #16    ; Rotate left s=16 bits
  eor	x.r6, x.r17, x.r4    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r13, #0x1d05    ; Load lower half of constant 0x4881d05
  add	w.r8, w.r17, w.r8    ; Add X parameter round 3 C=HH(C, D, A, B, 0xd4ef3085, s=16, M[3])
  movk	x.r13, #0x488, lsl #16    ; Load upper half of constant 0x4881d05
  add	w.r9, w.r9, w.r7    ; Add dest value
  eor	x.r6, x.r6, x.r8    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r9, w.r9, w.r13    ; Add constant 0x4881d05
  add	w.r9, w.r9, w.r6    ; Add aux function result
  eor	x.r6, x.r8, x.r17    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r9, w.r9, #9    ; Rotate left s=23 bits
  movz	x.r10, #0xd039    ; Load lower half of constant 0xd9d4d039
  add	w.r9, w.r8, w.r9    ; Add X parameter round 3 B=HH(B, C, D, A, 0x4881d05, s=23, M[6])
  movk	x.r10, #0xd9d4, lsl #16    ; Load upper half of constant 0xd9d4d039
  add	w.r4, w.r4, w.r24    ; Add dest value
  eor	x.r6, x.r6, x.r9    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r4, w.r4, w.r10    ; Add constant 0xd9d4d039
  add	w.r4, w.r4, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #28    ; Rotate left s=4 bits
  eor	x.r6, x.r9, x.r8    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r10, #0x99e5    ; Load lower half of constant 0xe6db99e5
  add	w.r4, w.r9, w.r4    ; Add X parameter round 3 A=HH(A, B, C, D, 0xd9d4d039, s=4, M[9])
  movk	x.r10, #0xe6db, lsl #16    ; Load upper half of constant 0xe6db99e5
  add	w.r17, w.r17, w.r11    ; Add dest value
  eor	x.r6, x.r6, x.r4    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r17, w.r17, w.r10    ; Add constant 0xe6db99e5
  add	w.r17, w.r17, w.r6    ; Add aux function result
  eor	x.r6, x.r4, x.r9    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  ror	w.r17, w.r17, #21    ; Rotate left s=11 bits
  movz	x.r13, #0x7cf8    ; Load lower half of constant 0x1fa27cf8
  add	w.r17, w.r4, w.r17    ; Add X parameter round 3 D=HH(D, A, B, C, 0xe6db99e5, s=11, M[12])
  movk	x.r13, #0x1fa2, lsl #16    ; Load upper half of constant 0x1fa27cf8
  add	w.r8, w.r8, w.r27    ; Add dest value
  eor	x.r6, x.r6, x.r17    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r8, w.r8, w.r13    ; Add constant 0x1fa27cf8
  add	w.r8, w.r8, w.r6    ; Add aux function result
  ror	w.r8, w.r8, #16    ; Rotate left s=16 bits
  eor	x.r6, x.r17, x.r4    ; Begin aux function round 3 H(x,y,z)=(x^y^z)
  movz	x.r13, #0x5665    ; Load lower half of constant 0xc4ac5665
  add	w.r8, w.r17, w.r8    ; Add X parameter round 3 C=HH(C, D, A, B, 0x1fa27cf8, s=16, M[15])
  movk	x.r13, #0xc4ac, lsl #16    ; Load upper half of constant 0xc4ac5665
  add	w.r9, w.r9, w.r3    ; Add dest value
  eor	x.r6, x.r6, x.r8    ; End aux function round 3 H(x,y,z)=(x^y^z)
  add	w.r9, w.r9, w.r13    ; Add constant 0xc4ac5665
  add	w.r9, w.r9, w.r6    ; Add aux function result
  ror	w.r9, w.r9, #9    ; Rotate left s=23 bits
  movz	x.r6, #0x2244    ; Load lower half of constant 0xf4292244
  movk	x.r6, #0xf429, lsl #16    ; Load upper half of constant 0xf4292244
  add	w.r9, w.r8, w.r9    ; Add X parameter round 3 B=HH(B, C, D, A, 0xc4ac5665, s=23, M[2])
  add	w.r4, w.r4, w.r15    ; Add dest value
  orn	x.r13, x.r9, x.r17    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r4, w.r4, w.r6    ; Add constant 0xf4292244
  eor	x.r6, x.r8, x.r13    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r4, w.r4, w.r6    ; Add aux function result
  ror	w.r4, w.r4, #26    ; Rotate left s=6 bits
  movz	x.r6, #0xff97    ; Load lower half of constant 0x432aff97
  movk	x.r6, #0x432a, lsl #16    ; Load upper half of constant 0x432aff97
  add	w.r4, w.r9, w.r4    ; Add X parameter round 4 A=II(A, B, C, D, 0xf4292244, s=6, M[0])
  orn	x.r10, x.r4, x.r8    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r17, w.r17, w.r23    ; Add dest value
  eor	x.r10, x.r9, x.r10    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r17, w.r17, w.r6    ; Add constant 0x432aff97
  add	w.r6, w.r17, w.r10    ; Add aux function result
  ror	w.r6, w.r6, #22    ; Rotate left s=10 bits
  movz	x.r17, #0x23a7    ; Load lower half of constant 0xab9423a7
  movk	x.r17, #0xab94, lsl #16    ; Load upper half of constant 0xab9423a7
  add	w.r6, w.r4, w.r6    ; Add X parameter round 4 D=II(D, A, B, C, 0x432aff97, s=10, M[7])
  add	w.r8, w.r8, w.r12    ; Add dest value
  orn	x.r10, x.r6, x.r9    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r8, w.r17    ; Add constant 0xab9423a7
  eor	x.r17, x.r4, x.r10    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r8, w.r17    ; Add aux function result
  ror	w.r8, w.r8, #17    ; Rotate left s=15 bits
  movz	x.r17, #0xa039    ; Load lower half of constant 0xfc93a039
  movk	x.r17, #0xfc93, lsl #16    ; Load upper half of constant 0xfc93a039
  add	w.r8, w.r6, w.r8    ; Add X parameter round 4 C=II(C, D, A, B, 0xab9423a7, s=15, M[14])
  orn	x.r13, x.r8, x.r4    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r9, w.r22    ; Add dest value
  eor	x.r13, x.r6, x.r13    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r9, w.r17    ; Add constant 0xfc93a039
  add	w.r17, w.r9, w.r13    ; Add aux function result
  ror	w.r17, w.r17, #11    ; Rotate left s=21 bits
  movz	x.r9, #0x59c3    ; Load lower half of constant 0x655b59c3
  movk	x.r9, #0x655b, lsl #16    ; Load upper half of constant 0x655b59c3
  add	w.r17, w.r8, w.r17    ; Add X parameter round 4 B=II(B, C, D, A, 0xfc93a039, s=21, M[5])
  add	w.r4, w.r4, w.r11    ; Add dest value
  orn	x.r13, x.r17, x.r6    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r4, w.r9    ; Add constant 0x655b59c3
  eor	x.r4, x.r8, x.r13    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r9, w.r4    ; Add aux function result
  ror	w.r9, w.r9, #26    ; Rotate left s=6 bits
  movz	x.r4, #0xcc92    ; Load lower half of constant 0x8f0ccc92
  movk	x.r4, #0x8f0c, lsl #16    ; Load upper half of constant 0x8f0ccc92
  add	w.r9, w.r17, w.r9    ; Add X parameter round 4 A=II(A, B, C, D, 0x655b59c3, s=6, M[12])
  orn	x.r10, x.r9, x.r8    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r6, w.r6, w.r21    ; Add dest value
  eor	x.r10, x.r17, x.r10    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r4, w.r6, w.r4    ; Add constant 0x8f0ccc92
  add	w.r6, w.r4, w.r10    ; Add aux function result
  ror	w.r6, w.r6, #22    ; Rotate left s=10 bits
  movz	x.r4, #0xf47d    ; Load lower half of constant 0xffeff47d
  movk	x.r4, #0xffef, lsl #16    ; Load upper half of constant 0xffeff47d
  add	w.r6, w.r9, w.r6    ; Add X parameter round 4 D=II(D, A, B, C, 0x8f0ccc92, s=10, M[3])
  add	w.r8, w.r8, w.r16    ; Add dest value
  orn	x.r10, x.r6, x.r17    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r8, w.r4    ; Add constant 0xffeff47d
  eor	x.r4, x.r9, x.r10    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r8, w.r4    ; Add aux function result
  ror	w.r8, w.r8, #17    ; Rotate left s=15 bits
  movz	x.r4, #0x5dd1    ; Load lower half of constant 0x85845dd1
  movk	x.r4, #0x8584, lsl #16    ; Load upper half of constant 0x85845dd1
  add	w.r8, w.r6, w.r8    ; Add X parameter round 4 C=II(C, D, A, B, 0xffeff47d, s=15, M[10])
  orn	x.r10, x.r8, x.r9    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r17, w.r20    ; Add dest value
  eor	x.r17, x.r6, x.r10    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r15, w.r4    ; Add constant 0x85845dd1
  add	w.r4, w.r15, w.r17    ; Add aux function result
  ror	w.r4, w.r4, #11    ; Rotate left s=21 bits
  movz	x.r15, #0x7e4f    ; Load lower half of constant 0x6fa87e4f
  movk	x.r15, #0x6fa8, lsl #16    ; Load upper half of constant 0x6fa87e4f
  add	w.r17, w.r8, w.r4    ; Add X parameter round 4 B=II(B, C, D, A, 0x85845dd1, s=21, M[1])
  add	w.r4, w.r9, w.r5    ; Add dest value
  orn	x.r9, x.r17, x.r6    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r4, w.r15    ; Add constant 0x6fa87e4f
  eor	x.r4, x.r8, x.r9    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r15, w.r4    ; Add aux function result
  ror	w.r9, w.r9, #26    ; Rotate left s=6 bits
  movz	x.r15, #0xe6e0    ; Load lower half of constant 0xfe2ce6e0
  movk	x.r15, #0xfe2c, lsl #16    ; Load upper half of constant 0xfe2ce6e0
  add	w.r4, w.r17, w.r9    ; Add X parameter round 4 A=II(A, B, C, D, 0x6fa87e4f, s=6, M[8])
  orn	x.r9, x.r4, x.r8    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r6, w.r6, w.r27    ; Add dest value
  eor	x.r9, x.r17, x.r9    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r6, w.r15    ; Add constant 0xfe2ce6e0
  add	w.r6, w.r15, w.r9    ; Add aux function result
  ror	w.r6, w.r6, #22    ; Rotate left s=10 bits
  movz	x.r9, #0x4314    ; Load lower half of constant 0xa3014314
  movk	x.r9, #0xa301, lsl #16    ; Load upper half of constant 0xa3014314
  add	w.r15, w.r4, w.r6    ; Add X parameter round 4 D=II(D, A, B, C, 0xfe2ce6e0, s=10, M[15])
  add	w.r6, w.r8, w.r7    ; Add dest value
  orn	x.r7, x.r15, x.r17    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r6, w.r9    ; Add constant 0xa3014314
  eor	x.r9, x.r4, x.r7    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r6, w.r8, w.r9    ; Add aux function result
  ror	w.r6, w.r6, #17    ; Rotate left s=15 bits
  movz	x.r7, #0x11a1    ; Load lower half of constant 0x4e0811a1
  movk	x.r7, #0x4e08, lsl #16    ; Load upper half of constant 0x4e0811a1
  add	w.r8, w.r15, w.r6    ; Add X parameter round 4 C=II(C, D, A, B, 0xa3014314, s=15, M[6])
  orn	x.r9, x.r8, x.r4    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r6, w.r17, w.r26    ; Add dest value
  eor	x.r17, x.r15, x.r9    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r9, w.r6, w.r7    ; Add constant 0x4e0811a1
  add	w.r7, w.r9, w.r17    ; Add aux function result
  ror	w.r7, w.r7, #11    ; Rotate left s=21 bits
  movz	x.r6, #0x7e82    ; Load lower half of constant 0xf7537e82
  movk	x.r6, #0xf753, lsl #16    ; Load upper half of constant 0xf7537e82
  add	w.r9, w.r8, w.r7    ; Add X parameter round 4 B=II(B, C, D, A, 0x4e0811a1, s=21, M[13])
  add	w.r17, w.r4, w.r14    ; Add dest value
  orn	x.r7, x.r9, x.r15    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r14, w.r17, w.r6    ; Add constant 0xf7537e82
  eor	x.r4, x.r8, x.r7    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r17, w.r14, w.r4    ; Add aux function result
  ror	w.r17, w.r17, #26    ; Rotate left s=6 bits
  movz	x.r6, #0xf235    ; Load lower half of constant 0xbd3af235
  movk	x.r6, #0xbd3a, lsl #16    ; Load upper half of constant 0xbd3af235
  add	w.r7, w.r9, w.r17    ; Add X parameter round 4 A=II(A, B, C, D, 0xf7537e82, s=6, M[4])
  orn	x.r14, x.r7, x.r8    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r4, w.r15, w.r25    ; Add dest value
  eor	x.r17, x.r9, x.r14    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r4, w.r6    ; Add constant 0xbd3af235
  add	w.r16, w.r15, w.r17    ; Add aux function result
  ror	w.r16, w.r16, #22    ; Rotate left s=10 bits
  movz	x.r14, #0xd2bb    ; Load lower half of constant 0x2ad7d2bb
  movk	x.r14, #0x2ad7, lsl #16    ; Load upper half of constant 0x2ad7d2bb
  add	w.r4, w.r7, w.r16    ; Add X parameter round 4 D=II(D, A, B, C, 0xbd3af235, s=10, M[11])
  add	w.r6, w.r8, w.r3    ; Add dest value
  orn	x.r15, x.r4, x.r9    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r17, w.r6, w.r14    ; Add constant 0x2ad7d2bb
  eor	x.r16, x.r7, x.r15    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r8, w.r17, w.r16    ; Add aux function result
  ror	w.r8, w.r8, #17    ; Rotate left s=15 bits
  movz	x.r3, #0xd391    ; Load lower half of constant 0xeb86d391
  movk	x.r3, #0xeb86, lsl #16    ; Load upper half of constant 0xeb86d391
  add	w.r14, w.r4, w.r8    ; Add X parameter round 4 C=II(C, D, A, B, 0x2ad7d2bb, s=15, M[2])
  orn	x.r6, x.r14, x.r7    ; Begin aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r15, w.r9, w.r24    ; Add dest value
  eor	x.r17, x.r4, x.r6    ; End aux function round 4 I(x,y,z)=((~z|x)^y)
  add	w.r16, w.r15, w.r3    ; Add constant 0xeb86d391
  add	w.r8, w.r16, w.r17    ; Add aux function result
  ror	w.r8, w.r8, #11    ; Rotate left s=21 bits
  ldp	w.r6, w.r15, [x.st]    ; Reload MD5 state->A and state->B
  ldp	w.r5, w.r9, [x.st, #8]    ; Reload MD5 state->C and state->D
  add	w.r3, w.r14, w.r8    ; Add X parameter round 4 B=II(B, C, D, A, 0xeb86d391, s=21, M[9])
  add	w.r13, w.r4, w.r9    ; Add result of MD5 rounds to state->D
  add	w.r12, w.r14, w.r5    ; Add result of MD5 rounds to state->C
  add	w.r10, w.r7, w.r6    ; Add result of MD5 rounds to state->A
  add	w.r11, w.r3, w.r15    ; Add result of MD5 rounds to state->B
  stp	w.r12, w.r13, [x.st, #8]    ; Store MD5 states C,D
  stp	w.r10, w.r11, [x.st]    ; Store MD5 states A,B
  add	x.data, x.data, #64    ; Increment data pointer
  subs	w.num, w.num, #1    ; Decrement block counter
  b.ne	loop
  .restore all
  ret
.end
