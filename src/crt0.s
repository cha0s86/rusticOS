# 32-bit startup code for RusticOS
# Sets up stack and calls kernel_main

.global _start
.extern kernel_main

.section .text
.code32

_start:
    # Disable interrupts
    cli
    
    # Set up segment registers
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    
    # Set up stack
    mov $0x90000, %esp
    
    # Call C++ kernel main function
    call kernel_main
    
    # Should never return, but if it does, halt
.hang:
    hlt
    jmp .hang 