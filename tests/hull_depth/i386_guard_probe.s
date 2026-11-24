.globl _start
.text
_start:
  mov $359, %eax        # i386 socket syscall
  mov $2, %ebx          # AF_INET
  mov $1, %ecx          # SOCK_STREAM
  xor %edx, %edx
  int $0x80
  cmp $-1, %eax         # -EPERM
  je ok
  mov $1, %ebx
  jmp exit
ok:
  xor %ebx, %ebx
exit:
  mov $1, %eax
  int $0x80
