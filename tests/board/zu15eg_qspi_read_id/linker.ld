ENTRY(_start)

SECTIONS
{
    . = 0xFFFC0000;
    .text : {
        KEEP(*(.text.start))
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }

    . = 0xFFFE0000;
    .mailbox : { KEEP(*(.mailbox)) }

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
