/* Linker script for RusticOS 32-bit kernel */

ENTRY(_start)

/* Define sections */
SECTIONS
{
    /* Kernel starts at 1 MiB */
    . = 0x100000;
    
    /* Text section (code) */
    .text : {
        *(.text)
        *(.text.*)
    }
    
    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }
    
    /* Data section */
    .data : {
        *(.data)
        *(.data.*)
    }
    
    /* BSS section (uninitialized data) */
    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }
    
    /* Discard other sections */
    /DISCARD/ : {
        *(.comment)
        *(.note)
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
} 