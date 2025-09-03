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

    # DEBUG: Write 'C' at VGA row 9 to confirm crt0.s entry
    mov $0xb8000, %edi
    add $(80*9*2), %edi
    mov $0x1f43, %eax   # 'C' white on blue
    mov %eax, (%edi)

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

    # Install minimal IDT for exceptions (0..31) to prevent triple faults
    # Fill IDT entries so all 0..31 vectors point to isr_common
    mov $isr_common, %eax
    mov %ax, %dx                # low 16 bits of handler
    shr $16, %eax
    mov %ax, %bx                # high 16 bits of handler
    lea idt_start, %edi
    mov $32, %ecx
.fill_idt:
    mov %dx, (%edi)             # offset low
    movw $0x0008, 2(%edi)       # selector
    movb $0x00, 4(%edi)         # zero
    movb $0x8E, 5(%edi)         # type and attributes
    mov %bx, 6(%edi)            # offset high
    add $8, %edi
    loop .fill_idt

    lea idt_descriptor, %eax
    lidt (%eax)

    # ------------------------------------------------------------------
    # Zero the .bss section to avoid undefined global state
    # ------------------------------------------------------------------
    cld
    mov $__bss_start, %edi
    mov $__bss_end, %ecx
    sub %edi, %ecx           # ECX = size of .bss in bytes
    xor %eax, %eax           # fill with zeros
    rep stosb

    # ------------------------------------------------------------------
    # Run C++ global constructors (init_array then ctors fallback)
    # ------------------------------------------------------------------
    # init_array: array of pointers to void (*)()
    mov $__init_array_start, %ebx
    mov $__init_array_end, %edx
.init_array_loop:
    cmp %ebx, %edx
    jge .after_init_array
    mov (%ebx), %eax
    add $4, %ebx
    test %eax, %eax
    jz .init_array_loop
    call *%eax
    jmp .init_array_loop
.after_init_array:

    # ctors section fallback (older toolchains)
    mov $__ctors_start, %ebx
    mov $__ctors_end, %edx
    cmp %ebx, %edx
    jge .after_ctors
.ctors_loop:
    cmp %ebx, %edx
    jge .after_ctors
    mov (%ebx), %eax
    add $4, %ebx
    test %eax, %eax
    jz .ctors_loop
    call *%eax
    jmp .ctors_loop
.after_ctors:

    # Call C++ kernel main function
    call kernel_main

    # If kernel_main returns, halt forever
.hang:
    hlt
    jmp .hang

# ------------------------------------------------------------------
# Minimal IDT for exceptions, all vectors 0..31 -> isr_common
# ------------------------------------------------------------------
.section .data
.align 8
idt_start:
    .rept 32
        .word 0                # offset low (filled at runtime)
        .word 0x08             # selector
        .byte 0                # zero
        .byte 0x8E             # type and attributes
        .word 0                # offset high (filled at runtime)
    .endr
idt_end:

idt_descriptor:
    .word idt_end - idt_start - 1
    .long idt_start

.section .text
.code32
isr_common:
    # Show 'X' at screen pos 0,1 and halt to indicate exception
    mov $0xb8008, %edi
    mov $0x4f58, %eax   # 'X' bright white on red
    mov %eax, (%edi)
.isr_hang:
    hlt
    jmp .isr_hang
