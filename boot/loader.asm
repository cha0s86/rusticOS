[org 0x0000]
[bits 16]

loader_start:
    ; Preserve boot drive passed in DL
    mov [boot_drive], dl

    ; Print: Loader started
    mov si, loader_msg_start
    call print_string

    ; Print: Loading kernel
    mov si, loader_msg_loading_kernel
    call print_string

    ; Load kernel from disk to 0x0010_0000 (ES:BX = 0x1000:0x0000)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02                 ; INT 13h read sectors
    mov al, [kernel_sectors]     ; Sectors to read
    xor ch, ch                   ; Cylinder 0
    mov cl, 2                    ; Start at sector 2 (sector 1 is loader)
    xor dh, dh                   ; Head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Print: Kernel loaded
    mov si, kernel_loaded_msg
    call print_string

    ; Enable A20 via port 0x92
    in al, 0x92
    or al, 0000_0010b
    out 0x92, al

    ; Set up GDT
    lgdt [gdt_descriptor]

    ; Print: Switching to protected mode
    mov si, loader_msg_pm_switch
    call print_string

    ; Enter protected mode: set PE bit in CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code segment to flush prefetch queue
    jmp 0x08:protected_mode_entry

[bits 32]
protected_mode_entry:
    ; Load data segments with data selector 0x10
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Jump to kernel entry at linear 0x0010_0000
    ; Assumes flat segments, paging disabled
    jmp 0x08:0x00100000

[bits 16]

; ----------------------
; Helpers and data
; ----------------------

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

; Messages
loader_msg_start db 'Loader: started', 13, 10, 0
loader_msg_loading_kernel db 'Loader: loading kernel...', 13, 10, 0
kernel_loaded_msg db 'Loader: kernel loaded', 13, 10, 0
loader_msg_pm_switch db 'Loader: switching to protected mode', 13, 10, 0

boot_drive db 0

%include "boot/kernel_sectors.inc"
kernel_sectors equ KERNEL_SECTORS

align 8
; GDT: null, code, data (flat, base=0, limit=4GB)
gdt_start:
    dq 0x0000000000000000
    dq 0x00cf9a000000ffff   ; Code segment: base=0, limit=4GB, 32-bit, RX
    dq 0x00cf92000000ffff   ; Data segment: base=0, limit=4GB, 32-bit, RW
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Pad to 512 bytes
times 512-($-$$) db 0

disk_error:
    mov si, disk_error_msg
    call print_string
.hang:
    hlt
    jmp .hang

disk_error_msg db 'Loader: disk read error', 13, 10, 0