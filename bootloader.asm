; Simple Bootloader for x86_64
; This bootloader loads the second-stage loader and jumps to it

[org 0x7c00]                    ; BIOS loads bootloader at 0x7c00
[bits 16]                       ; Start in 16-bit real mode

; Initialize segment registers
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    
    ; Preserve boot drive passed by BIOS in DL
    mov [boot_drive], dl

; Print welcome message
    mov si, welcome_msg
    call print_string

; Load second-stage loader from disk (sector 2) into 0000:8000
    xor ax, ax
    mov es, ax                  ; ES = 0 so ES:BX -> 0000:8000
    mov bx, 0x8000

    mov ah, 0x02                ; BIOS read sector(s)
    mov al, 1                   ; Read 1 sector (512 bytes)
    mov ch, 0                   ; Cylinder 0
    mov cl, 2                   ; Start at sector 2 (sector numbers are 1-based)
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]        ; Use the boot drive provided by BIOS
    int 0x13                    ; BIOS interrupt for disk operations
    
    jc disk_error               ; Jump if carry flag is set (error)

; Print success message
    mov si, load_success_msg
    call print_string

; Jump to second-stage loader
    jmp 0x0000:0x8000           ; Far jump to physical 0x0000:0x8000

; Print string function
print_string:
    lodsb                       ; Load byte from SI into AL
    or al, al                   ; Check if AL is zero (end of string)
    jz print_done              ; If zero, we're done
    mov ah, 0x0e               ; BIOS teletype function
    int 0x10                   ; BIOS interrupt for video
    jmp print_string           ; Repeat for next character
print_done:
    ret

; Disk error handler
disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $                       ; Infinite loop

; Data
boot_drive db 0
welcome_msg db 'RusticOS Bootloader Starting...', 13, 10, 0
load_success_msg db 'Second-stage loader loaded!', 13, 10, 0
disk_error_msg db 'Disk read error!', 13, 10, 0

; Boot signature
times 510-($-$$) db 0          ; Fill remaining bytes with zeros
dw 0xaa55                      ; Boot signature 