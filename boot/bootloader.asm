; Minimal MBR bootloader for RusticOS
[org 0x7c00]
[bits 16]

start:
    ; Debug: Print a message to confirm bootloader is running
    mov si, debug_msg
    call print_string

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov dl, 0x80           ; Assume hard disk (change to 0x00 for floppy)
    mov [boot_drive], dl   ; Pass boot drive to loader

    mov ax, 0x0800         ; ES = 0x0800
    mov es, ax
    mov bx, 0x0000         ; BX = 0x0000
    mov ah, 0x02           ; BIOS read sector(s)
    mov al, 1              ; Read 1 sector
    mov ch, 0
    mov cl, 1              ; Sector 1
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov si, welcome_msg
    call print_string
    mov si, load_success_msg
    call print_string

    ; Debug: Print a message before jumping
    mov si, jump_msg
    call print_string

    ; Set up segments for loader
    mov ax, 0x0800
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x8000

    ; Jump to loader
    jmp 0x0000      ; Jump to offset 0x0000 in segment 0x0800 (physical 0x8000)

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
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

times 510-($-$$) db 0

; Boot signature
    dw 0xaa55