[org 0x8000]
[bits 16]

%include "boot/kernel_sectors.inc"

loader_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Print message
    mov si, loader_msg
    call print_string
    mov si, seg_set_msg
    call serial_out

    ; Ensure boot_drive is set by bootloader
    ; (bootloader must do: mov [boot_drive], dl before jmp to loader)

    ; Load kernel (sectors 2..N) to 0x100000
    mov word [kernel_seg], 0x1000
    mov bl, 2          ; Start at sector 2
    mov cx, KERNEL_SECTORS         ; Number of sectors to load (auto from Makefile)
    xor bx, bx         ; Offset for ES:BX

[bits 16]
load_kernel_loop:
    mov ax, [kernel_seg]
    mov es, ax
    mov si, seg_set_msg
    call serial_out
    mov ah, 2
    mov al, 1
    mov ch, 0
    mov cl, bl
    mov dh, 0
    mov dl, byte [boot_drive]
    int 0x13
    jc disk_error
    mov si, read_ok_msg
    call serial_out

    add bx, 512
    cmp bx, 0x10000
    jb skip_inc_es
    mov ax, [kernel_seg]
    add ax, 0x10
    mov [kernel_seg], ax
    mov es, ax
    sub bx, 0x10000
skip_inc_es:
    inc bl
    loop load_kernel_loop

    ; Print PM switch message
    mov si, pm_msg
    call print_string

    ; Set up GDT in low memory
    lgdt [gdt_descriptor]

    ; Enable A20 (optional, usually already enabled)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Enter protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Far jump to kernel at 0x100000 (CS=0x08)
    jmp 0x08:0x100000

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

; Serial debug routine (COM1, port 0x3F8)
serial_out:
    mov dx, 0x3F8
    mov al, [si]
    out dx, al
    inc si
    ret

loader_msg db 'Loader: Loading kernel...', 13, 10, 0
seg_set_msg db 'Set ES', 13, 10, 0
read_ok_msg db 'Read OK', 13, 10, 0
pm_msg db 'Switching to protected mode...', 13, 10, 0
disk_error_msg db 'Loader: Disk read error!', 13, 10, 0
boot_drive db 0    ; Must be set by bootloader: mov [boot_drive], dl

align 8
gdt_start:
    dq 0x0000000000000000
    dq 0x00cf9a000000ffff ; Code segment descriptor (limit=0xFFFF, base=0)
    dq 0x00cf92000000ffff ; Data segment descriptor (limit=0xFFFF, base=0)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

kernel_seg dw 0x1000

times 512-($-$$) db 0