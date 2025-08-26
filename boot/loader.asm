[org 0x0000]
[bits 16]

loader_start:
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0x7c00
    
    ; Make data segment equal to current code segment
    push cs
    pop ds
    
    ; ES = DS for 16-bit helpers
    mov ax, ds
    mov es, ax
    cld

    ; Preserve BIOS boot drive in DL
    mov [boot_drive], dl

    ; Print: Loader started
    mov si, loader_msg_start
    call print_string

    ; Enable A20 before any >1MiB access
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Print: Loading kernel
    mov si, loader_msg_loading_kernel
    call print_string

    ; Load kernel via CHS from LBA=2 => CHS (0,0,2) into 0x1000:0000 (linear 0x00010000)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02                 ; INT 13h read sectors
    mov al, kernel_sectors       ; Number of sectors to read
    xor ch, ch                   ; Cylinder 0
    mov cl, 2                    ; Start at sector 2 (LBA 2 => sector index 2)
    xor dh, dh                   ; Head 0
    mov dl, [boot_drive]
    
    ; Debug: Print sector count and drive
    push ax
    mov al, kernel_sectors
    call print_hex_byte
    mov si, sectors_msg
    call print_string
    pop ax
    
    int 0x13
    jc .disk_error_kernel
    
    ; Debug: Print success
    mov si, kernel_read_success_msg
    call print_string
    
    ; Print: Kernel loaded
    mov si, kernel_loaded_msg
    call print_string
    jmp .kernel_loaded_ok

.disk_error_kernel:
    mov si, kernel_read_error_msg
    call print_string
    ; Try to show error code
    mov al, ah
    call print_hex_byte
    mov si, newline_msg
    call print_string
    jmp disk_error

.kernel_loaded_ok:

    ; Build GDTR at runtime (32-bit linear base of GDT)
    mov word [gdt_descriptor], (gdt_end - gdt_start - 1)
    xor eax, eax
    mov ax, cs
    shl eax, 4                 ; EAX = CS base linear
    mov ebx, gdt_start         ; EBX = GDT offset
    add eax, ebx               ; EAX = linear(GDT)
    mov [gdt_descriptor+2], eax
    lgdt [gdt_descriptor]

    ; Print: Switching to protected mode
    mov si, loader_msg_pm_switch
    call print_string

    ; Enter protected mode (keep interrupts disabled)
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump using 32-bit offset to load 32-bit CS
    jmp dword 0x08:protected_mode_entry

[bits 32]
protected_mode_entry:
    ; Load flat data segments and set up a stack
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Copy kernel from 0x00010000 to 0x00100000 (kernel_sectors * 512 bytes)
    mov esi, 0x00010000
    mov edi, 0x00100000
    mov ecx, kernel_sectors
    shl ecx, 7                  ; *128 => sectors*512/4 dwords
    rep movsd

    ; Jump to kernel entry at 0x00100000 (flat segments)
    jmp 0x08:0x00100000

[bits 16]

; ----------------------
; Helpers and data (16-bit)
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
    dw 0
    dd 0

; Pad to 512 bytes
times 512-($-$$) db 0

disk_error:
    mov si, disk_error_msg
    call print_string
.hang:
    hlt
    jmp .hang

disk_error_msg db 'Loader: disk read error', 13, 10, 0