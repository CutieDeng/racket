// alloca_sum(n): allocate n*16 bytes on the stack via a runtime-sized .alloca,
// fill the region, sum it back, and return the sum. Exercises .frame (fp) +
// variable-length stack allocation + fp-based sp restore in the epilogue.
// Correct return AND no crash proves the frame is ABI-correct (sp restored).
.function alloca_sum export ()
entry:
  .save all
  .frame
  .alloca x0, 4            // sp -= n*16  (n 16-byte blocks)
  mov x3, x0              // x3 = n (loop count of 16-byte pairs)
  mov x4, sp             // x4 = base of allocated region
  mov x5, xzr            // running index i (0..n)
  mov x6, xzr            // fill value counter
fill:
  cbz x3, filled
  str x6, [x4]           // region[i].lo = counter
  add x7, x6, #1
  str x7, [x4, #8]       // region[i].hi = counter+1
  add x6, x6, #2
  add x4, x4, #16
  sub x3, x3, #1
  b fill
filled:
  // sum all words written back: values 0,1,2,...,2n-1 -> sum = n*(2n-1)
  mov x4, sp
  mov x3, x0
  mov x0, xzr            // accumulator
sum:
  cbz x3, done
  ldr x9, [x4]
  add x0, x0, x9
  ldr x9, [x4, #8]
  add x0, x0, x9
  add x4, x4, #16
  sub x3, x3, #1
  b sum
done:
  .restore all           // -> mov sp, x29 ; ldp x29, x30, [sp], #N
  ret
