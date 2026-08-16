.text
.extern extvar
.globl reloc_user
.type reloc_user, %function
reloc_user:
  adrp x0, :got:extvar
  ldr x0, [x0, :got_lo12:extvar]
  ret
.size reloc_user, .-reloc_user
