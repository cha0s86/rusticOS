; Simple Kernel for RusticOS
; This kernel is loaded by the bootloader and provides basic OS functionality

[org 0x8000]                    ; Kernel is loaded at 0x8000
[bits 16]                       ; Stay in 16-bit mode for simplicity

; Ensure DS=0, ES=0 for BIOS calls that may rely on it
    xor ax, ax
    mov ds, ax
    mov es, ax

; Kernel entry point at physical 0x8000
kernel_start:
    ; Clear the screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Print kernel welcome message
    mov si, kernel_welcome
    call kernel_print

    ; Print some basic system info
    mov si, system_info
    call kernel_print

    ; Enter infinite loop (simple OS behavior)
    jmp kernel_loop

; Kernel print function
kernel_print:
    lodsb                       ; Load byte from SI into AL
    or al, al                   ; Check if AL is zero
    jz kernel_print_done        ; If zero, we're done
    mov ah, 0x0e               ; BIOS teletype function
    int 0x10                   ; BIOS interrupt for video
    jmp kernel_print           ; Repeat for next character
kernel_print_done:
    ret

; Main kernel loop
kernel_loop:
    ; Simple idle loop - in a real OS, this would handle tasks
    hlt                         ; Halt CPU until next interrupt
    jmp kernel_loop

; Data
kernel_welcome db 'Welcome to RusticOS!', 13, 10, 0
system_info db 'Simple x86_64 Operating System', 13, 10, 'Built with NASM and QEMU', 13, 10, 0

; Fill the rest of the sector
times 512-($-$$) db 0 