// bn_sqr frame-layout probe (physical regs): .save all + .frame 32 + .alloca x5,4.
// Goal: show asmp reproduces bn_sqr_mont_8w's frame anatomy — callee-saved
// x19-x28 at [x29,#16..80], FP locals at [x29,#96/104/112], fixed frame 128,
// runtime tp = sp - num*16.
.function bn_sqr_skel export ()
entry:
  .save all
  .frame 32
  .alloca x5, 4                // sub sp, sp, x5, lsl #4  (x5 = num words)
  str x0, [x29, #96]           // offload rp   (FP-relative local)
  str x3, [x29, #104]          // offload np
  str x4, [x29, #112]          // offload n0
  mov x2, sp                   // tp = post-alloca sp
  // touch x19-x28 so .save all covers all ten callee-saved
  mov x19, xzr
  mov x20, xzr
  mov x21, xzr
  mov x22, xzr
  mov x23, xzr
  mov x24, xzr
  mov x25, xzr
  mov x26, xzr
  mov x27, xzr
  mov x28, xzr
  add x19, x19, x2
  ldr x0, [x29, #96]
  .restore all
  ret
