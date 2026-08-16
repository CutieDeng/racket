.asmp.function _start export
  mov x0, #1
  adrp x1, :pg_hi21:hello_msg
  add x1, x1, #:lo12:hello_msg
  mov x2, #22
  mov x8, #64
  svc #0

  mov x0, #0
  mov x8, #93
  svc #0
.asmp.end_function

.section .rodata
hello_msg:
  .ascii "hello world from asmp\n"
