# ============================================================================
# RusticOS - 32-bit Startup (crt0)
# ----------------------------------------------------------------------------
# Purpose:
#   - CPU already in protected mode (set by the loader)
#   - Set up flat data segments and a stack
#   - Call C++ kernel_main()
#
# Environment:
#   - GDT already loaded by the loader with code selector=0x08, data=0x10
#   - We are linked to 1 MiB (see linker.ld)
#   - VGA text buffer at 0xB8000
#
# Notes:
#   - Uses .code32 and SysV-like calling conventions for C
#   - This file is freestanding: no libc
# ============================================================================

.global _start
.extern kernel_main

.section .text
.code32

_start:
    # Disable interrupts while we set up segments/stack
    cli

    # Load data segments (match GDT entries set by loader)
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    # Set up a 32-bit stack (grows down)
    mov $0x90000, %esp

    # Optional debug: write 'K' at top-left of VGA text buffer
    mov $0xb8000, %edi
    mov $0x1f4b, %eax   # 'K' white on blue
    mov %eax, (%edi)

    # Call C++ kernel main function
    call kernel_main

    # If kernel_main returns, halt forever
.hang:
    hlt
    jmp .hang
