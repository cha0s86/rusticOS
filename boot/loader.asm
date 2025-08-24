; Second-stage loader for RusticOS
; Switches from 16-bit real mode to 32-bit protected mode
; Loads the kernel and jumps to it

[org 0x8000]                    ; Loaded by bootloader at 0x8000
[bits 16]                       ; Start in 16-bit real mode

; Constants
KERNEL_LOAD_ADDR equ 0x100000    ; 1 MiB
KERNEL_START_SECTOR equ 3         ; Start from sector 3 (kernel location - BIOS sectors start from 1)

; Entry point
loader_start:
    ; Save boot drive
    mov [boot_drive], dl
    
    ; Print loading message
    mov si, loading_msg
    call print_string
    
    ; Load kernel from disk to 1 MiB
    call load_kernel
    
    ; Print success message
    mov si, success_msg
    call print_string
    
    ; Switch to protected mode
    call switch_to_protected_mode
    
    ; This should never be reached
    jmp $

; Load kernel from disk
load_kernel:
    ; Print debug info
    mov si, debug_msg
    call print_string
    
    ; Print drive number
    mov si, drive_msg
    call print_string
    mov al, [boot_drive]
    call print_hex
    
    ; Load to segment 0x7000 (0x7000 * 16 = 0x70000 = 448KB) - safe in real mode
    mov ax, 0x7000
    mov es, ax
    mov bx, 0x0000              ; Offset 0 in segment 0x7000 = 0x70000
    
    ; Try to read one sector first to test
    mov ah, 0x02                ; BIOS read sector function
    mov al, 1                   ; Read 1 sector first
    mov ch, 0                   ; Cylinder 0
    mov cl, KERNEL_START_SECTOR ; Start sector
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]        ; Drive number
    
    ; Print sector number
    mov si, sector_msg
    call print_string
    mov al, cl
    call print_hex
    
    int 0x13                    ; BIOS interrupt
    
    ; Check for error and print details
    jc disk_error_detailed      ; Jump if error
    
    ; Print success message for first sector
    mov si, first_sector_msg
    call print_string
    
    ; Now try to read the remaining sectors
    mov ah, 0x02                ; BIOS read sector function
    mov al, 10                  ; Read remaining 10 sectors
    mov ch, 0                   ; Cylinder 0
    mov cl, KERNEL_START_SECTOR + 1 ; Start from next sector
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]        ; Drive number
    mov bx, 0x0200              ; Offset 512 bytes in segment 0x7000
    
    int 0x13                    ; BIOS interrupt
    
    ; Check for error and print details
    jc disk_error_detailed      ; Jump if error
    
    ; Print success message
    mov si, read_success_msg
    call print_string
    
    ret

; Switch to protected mode
switch_to_protected_mode:
    ; Disable interrupts
    cli
    
    ; Enable A20 line
    call enable_a20
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Set protection enable bit
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to 32-bit code
    jmp 0x08:protected_mode_entry

; Enable A20 line
enable_a20:
    ; Try fast A20 method first
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

; Print string function (16-bit)
print_string:
    lodsb
    or al, al
    jz print_done
    mov ah, 0x0e
    int 0x10
    jmp print_string
print_done:
    ret

; Print hex function (16-bit)
print_hex:
    push ax
    shr al, 4
    call print_hex_digit
    pop ax
    and al, 0x0f
    call print_hex_digit
    ret

print_hex_digit:
    cmp al, 9
    jle .digit
    add al, 'A' - '0' - 10
.digit:
    add al, '0'
    mov ah, 0x0e
    int 0x10
    ret

; Disk error handler with detailed info
disk_error_detailed:
    mov si, error_detailed_msg
    call print_string
    
    ; Print the error code from AH
    mov al, ah
    call print_hex
    
    mov si, newline
    call print_string
    jmp $

; Simple disk error handler
disk_error:
    mov si, error_msg
    call print_string
    jmp $

; Data
boot_drive db 0
loading_msg db 'Loading kernel...', 13, 10, 0
success_msg db 'Kernel loaded! Switching to protected mode...', 13, 10, 0
error_msg db 'Disk read error!', 13, 10, 0
debug_msg db 'Reading from sector 3, 11 sectors...', 13, 10, 0
read_success_msg db 'Disk read successful!', 13, 10, 0
drive_msg db 'Drive: ', 0
sector_msg db 'Sector: ', 0
error_detailed_msg db 'Disk read failed! Error code: ', 0
newline db 13, 10, 0
first_sector_msg db 'First sector read successful!', 13, 10, 0

; Disk address packet for extended read
disk_address_packet:
    db 0x10                     ; Packet size (16 bytes)
    db 0                        ; Reserved
    dw 11                       ; Number of sectors to read
    dd 0x70000                  ; Transfer buffer address
    dq 3                        ; Starting LBA (sector 3)

; GDT (Global Descriptor Table)
gdt:
    ; Null descriptor
    dq 0
    
    ; Code segment descriptor (0x08) - base 0, limit 4GB
    dw 0xffff                   ; Limit 15:0
    dw 0x0000                   ; Base 15:0
    db 0x00                     ; Base 23:16
    db 10011010b                ; Access byte (code, readable, non-conforming, ring 0)
    db 11001111b                ; Flags + Limit 19:16 (4KB granularity, 32-bit, limit 19:16 = 0xF)
    db 0x00                     ; Base 31:24
    
    ; Data segment descriptor (0x10) - base 0, limit 4GB
    dw 0xffff                   ; Limit 15:0
    dw 0x0000                   ; Base 23:16
    db 0x00                     ; Base 23:16
    db 10010010b                ; Access byte (data, writable, expand up, ring 0)
    db 11001111b                ; Flags + Limit 19:16 (4KB granularity, 32-bit, limit 19:16 = 0xF)
    db 0x00                     ; Base 31:24

gdt_descriptor:
    dw gdt_descriptor - gdt - 1 ; GDT size
    dd gdt                      ; GDT address

; Fill to 512 bytes
times 512-($-$$) db 0

; 32-bit protected mode entry point
[bits 32]
protected_mode_entry:
    ; Set up segment registers
    mov ax, 0x10                ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack at a safe location
    mov esp, 0x80000            ; Stack at 0x80000 (512KB)
    
    ; Copy kernel from 0x70000 to 0x100000
    call copy_kernel_to_1mb
    
    ; Jump to kernel at 1 MiB
    jmp 0x08:0x100000          ; Far jump to code segment 0x08, offset 0x100000

; Copy kernel from 0x70000 to 0x100000
copy_kernel_to_1mb:
    ; Set up source and destination
    mov esi, 0x70000            ; Source: kernel loaded at 0x70000
    mov edi, 0x100000           ; Destination: kernel should be at 0x100000
    
    ; Copy 5.5KB (11 sectors * 512 bytes)
    mov ecx, 0x1600             ; 5.5KB in dwords (0x1600 = 5632 bytes / 4 = 1408 dwords)
    rep movsd                    ; Copy dwords
    
    ret 