; Minimal MBR bootloader for RusticOS
[org 0x7c00]
[bits 16]

%include "boot/loader_sectors.inc"

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Preserve BIOS drive in DL
    mov [boot_drive], dl

    ; Zero out 0x10000 before disk read (diagnostic)
    mov ax, 0x1000
    mov es, ax
    xor di, di
    mov cx, 512/2
    xor ax, ax
.clear_loop:
    stosw
    loop .clear_loop

    ; Read second-stage loader (starting at LBA 1 => CHS (0,0,2)) to 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ah, 0x02           ; BIOS read sector(s)
    mov al, LOADER_SECTORS ; read entire loader
    mov ch, 0
    mov cl, 2              ; sector 2 (LBA 1)
    mov dh, 0
    mov dl, [boot_drive]

    mov bp, 3              ; retry count
.read_retry:
    int 0x13
    jnc .read_ok
    ; on error, reset disk and retry
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    dec bp
    jnz .read_retry
    jc disk_error
.read_ok:

    mov si, msg_ok
    call print_string

    ; Debug: print first 4 bytes at 0x10000
    mov ax, 0x1000
    mov ds, ax
    xor si, si
    mov al, [si]
    call print_hex_byte
    mov al, [si+1]
    call print_hex_byte
    mov al, [si+2]
    call print_hex_byte
    mov al, [si+3]
    call print_hex_byte

    ; Restore DL for the loader
    mov dl, [boot_drive]

    ; Far jump to loader (use far jmp to flush prefetch queue)
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
    push bx
    mov bl, al
    shr al, 4
    call .nibble
    mov al, bl
    and al, 0x0F
    call .nibble
    mov al, ' '
    mov ah, 0x0e
    int 0x10
    pop bx
    pop ax
    ret
.nibble:
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .out
.digit:
    add al, '0'
.out:
    mov ah, 0x0e
    int 0x10
    ret

disk_error:
    mov si, msg_err
    call print_string
    cli
    hlt
    jmp $

boot_drive db 0

msg_ok db 'Loader loaded!', 13, 10, 0
msg_err db 'Disk read error!', 13, 10, 0

times 510-($-$$) db 0
dw 0xaa55