.function frame_local export ()
entry:
  .save all
  .frame 16
  str x0, [x29, #16]
  mov x0, #0
  ldr x1, [x29, #16]
  add x0, x1, #100
  .restore all
  ret
