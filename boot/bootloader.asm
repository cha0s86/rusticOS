; Minimal MBR bootloader for RusticOS
[org 0x7c00]
[bits 16]

start:
    cli
    ; Ensure DS=CS for string prints
    push cs
    pop ds

    mov si, debug_msg
    call print_string

    ; Set up segments
    xor ax, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Preserve BIOS boot drive in DL
    mov [boot_drive], dl

    ; Load second-stage (CHS C=0,H=0,S=2) to 0x1000:0000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02        ; read sectors
    mov al, 1           ; 1 sector
    xor ch, ch          ; cylinder 0
    mov cl, 2           ; sector 2
    xor dh, dh          ; head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Debug: Print what we loaded
    mov si, debug_loaded_msg
    call print_string
    
    ; Print first few bytes loaded
    mov al, [es:bx]
    call print_hex_byte
    mov al, [es:bx+1]
    call print_hex_byte
    mov al, [es:bx+2]
    call print_hex_byte
    mov al, [es:bx+3]
    call print_hex_byte
    mov si, newline_msg
    call print_string

    ; Quick sanity check: first byte non-zero
    cmp byte [es:bx], 0
    je disk_error
    
    ; Stronger check: first byte should be 0xFA (cli instruction)
    cmp byte [es:bx], 0xFA
    jne disk_error

    mov si, welcome_msg
    call print_string
    mov si, load_success_msg
    call print_string

    mov si, jump_msg
    call print_string

    ; Set up segment registers for the jump
    mov ax, 0x1000
    mov ds, ax
    mov es, ax

    ; Far jump to loader at 0x1000:0x0000
    jmp 0x1000:0x0000

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

print_hex_byte:
    push ax
    shr al, 4
    call .nibble
    pop ax
    and al, 0x0f
    call .nibble
    mov al, ' '
    mov ah, 0x0e
    int 0x10
    ret
.nibble:
    cmp al, 10
    jl .digit
    add al, 'a' - 10
    jmp .print
.digit:
    add al, '0'
.print:
    mov ah, 0x0e
    int 0x10
    ret

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

boot_drive db 0

welcome_msg db 'RusticOS Bootloader Starting...', 13, 10, 0
load_success_msg db 'Second-stage loader loaded!', 13, 10, 0
disk_error_msg db 'Disk read error!', 13, 10, 0
jump_msg db 'Attempting jump...', 13, 10, 0
debug_msg db 'Bootloader is running...', 13, 10, 0
debug_loaded_msg db 'Second-stage loaded to 0x1000:0000', 13, 10, 0
newline_msg db 13, 10, 0

times 510-($-$$) db 0

    dw 0xaa55