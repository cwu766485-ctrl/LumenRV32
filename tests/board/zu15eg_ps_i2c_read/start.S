.section .text.start, "ax"
.global _start
.type _start, %function
_start:
    ldr x0, =0xFFFFFFF0
    mov sp, x0
    bl main
1:
    wfe
    b 1b
.size _start, . - _start
