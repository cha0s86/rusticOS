[org 0x10000]
[bits 16]

; Determine kernel size in sectors
; Priority:
;   1) -D KERNEL_SIZE_BYTES=<bytes> on the NASM command line
;   2) boot/kernel_sectors.inc must define KERNEL_SECTORS
%ifndef KERNEL_SECTORS
%ifdef KERNEL_SIZE_BYTES
    %assign KERNEL_SECTORS ((KERNEL_SIZE_BYTES + 511) / 512)
%else
    %include "boot/kernel_sectors.inc"
%endif
%endif

kernel_sectors      equ KERNEL_SECTORS
SEG_BASE            equ 0x10000

loader_start:
    ; Real-mode init: DS = CS, stack to safe area
    cli
    push cs
    pop ds
    mov ax, 0x9000        ; Use a safe stack segment far from loader/data
    mov ss, ax 
    mov sp, 0xFFFE        ; Top of segment
    cld

    ; Save BIOS boot drive (DL)
    mov [boot_drive], dl

    ; Clear screen (BIOS)
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Print "Booting bootloader..." at row 2 (green on black)
    mov ax, 0xb800
    mov es, ax
    mov di, (80*2*2)
    mov si, bootloader_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color

    ; Print "Starting loader..." on line 3 (green on black)
    mov ax, 0xb800
    mov es, ax
    mov di, (80*3*2)
    mov si, loader_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color

    ; Prepare DAP for INT 13h Extensions (LBA) reads
    mov word [dap.count], 0              ; filled in loop
    mov word [dap.buf_off], 0x0000
    mov word [dap.buf_seg], 0x2000
    mov dword [dap.lba_low], 2            ; start at LBA 2 (kernel offset in image)
    mov dword [dap.lba_high], 0

    ; Ensure DS points to 0x1000 for DS:SI DAP pointer
    mov ax, 0x1000
    mov ds, ax

    ; Print "Loading kernel..." on line 4 (green on black)
    mov ax, 0xb800
    mov es, ax
    mov di, (80*4*2)
    mov si, loading_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color

    ; Remaining sectors to read
    mov bx, kernel_sectors
    mov [remaining], bx

read_lba_loop:
    mov bx, [remaining]
    cmp bx, 0
    je read_done

    ; Count = min(remaining, 127)  (BIOS often allows up to 127 per call)
    mov ax, bx
    cmp ax, 127
    jbe .count_ok
    mov ax, 127
.count_ok:
    mov [dap.count], ax

    ; INT 13h Extensions: AH=42h, DL=drive, ES:BX -> DAP
    mov ax, 0x1000
    mov es, ax
    mov bx, (dap - SEG_BASE)
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Advance buffer by count * 512 bytes -> segment += count * 32 paragraphs
    mov ax, [dap.count]
    shl ax, 5
    add [dap.buf_seg], ax

    ; Advance LBA by count (add to 64-bit LBA)
    mov ax, [dap.count]
    add [dap.lba_low], ax
    adc word [dap.lba_low+2], 0
    adc word [dap.lba_high+0], 0
    adc word [dap.lba_high+2], 0

    ; Decrease remaining
    sub [remaining], ax
    jmp read_lba_loop

read_done:
    ; Verify first byte at 0x00020000
    mov ax, 0x2000
    mov es, ax
    xor bx, bx
    mov al, [es:bx]
    cmp al, 0xFA
    jne disk_error

    ; Print "Booting kernel..." on line 5 (green on black)
    mov ax, 0xb800
    mov es, ax
    mov di, (80*5*2)
    mov si, booting_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color

    ; DEBUG: Print "PM jump" on line 6 before protected mode switch
    mov ax, 0xb800
    mov es, ax
    mov di, (80*6*2)
    mov si, pm_jump_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color

    ; Set up GDT for flat 32-bit protected mode
    lgdt [gdt_descriptor]

    ; Enable A20 via port 0x92
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Enter protected mode
    cli
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code segment to flush prefetch queue
    jmp dword 0x08:protected_mode_entry

[bits 32]
protected_mode_entry:
    ; DEBUG: Print "PM entry" at VGA row 7
    mov ax, 0x10
    mov es, ax
    mov edi, (0xB8000 + 80*7*2)
    mov esi, pm_entry_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color32

    ; Flat data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 32-bit stack (same as before)
    mov esp, 0x0090000

    ; Copy kernel from 0x00020000 to 0x00100000
    mov esi, 0x00020000
    mov edi, 0x00100000
    mov ecx, (kernel_sectors * 128)     ; sectors * 512 bytes / 4 bytes per dword
    rep movsd

    ; Verify copy: first byte at 0x00100000
    mov eax, dword [0x00100000]
    cmp al, 0xFA
    jne pm_copy_error

    ; DEBUG: Print "Kernel jump" at VGA row 8
    mov ax, 0x10
    mov es, ax
    mov edi, (0xB8000 + 80*8*2)
    mov esi, kernel_jump_msg
    mov ah, 0x02 ; green on black
    call print_string_vga_color32

    ; Jump to kernel entry (linked for 0x00100000)
    jmp dword 0x08:0x00100000

pm_copy_error:
    ; 32-bit: print E2 and halt
    mov ax, 0x10
    mov es, ax
    mov edi, 0
    mov al, 'E'
    mov ah, 0x04
    stosw
    mov al, '2'
    stosw
.halt32:
    cli
    hlt
    jmp .halt32

[bits 16]
disk_error:
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov al, 'E'
    mov ah, 0x04 ; red on black
    stosw
    mov al, 'R'
    stosw
    mov al, 'R'
    stosw
    cli
.halt:
    hlt
    jmp .halt

; Messages
bootloader_msg db 'Booting bootloader...',0
loader_msg     db 'Starting loader...',0
loading_msg    db 'Loading kernel...',0
booting_msg    db 'Booting kernel...',0
pm_jump_msg    db 'PM jump...',0
pm_entry_msg   db 'PM entry...',0
kernel_jump_msg db 'Kernel jump...',0

; Minimal VGA print routine (SI=string, DI=offset, AH=color)
print_string_vga_color:
    lodsb
    or al, al
    jz .done
    stosw
    jmp print_string_vga_color
.done:
    ret

; Minimal VGA print routine for 32-bit (ES:EDI, ESI=string, AH=color)
print_string_vga_color32:
    lodsb
    or al, al
    jz .done
    stosw
    jmp print_string_vga_color32
.done:
    ret

; ----------------------------------------------------------------------
; Data and tables
; ----------------------------------------------------------------------
align 8
gdt_start:
    dq 0x0000000000000000          ; null descriptor
    dq 0x00CF9A000000FFFF          ; code: base=0, limit=4GB, 32-bit, gran=4KB
    dq 0x00CF92000000FFFF          ; data: base=0, limit=4GB, 32-bit, gran=4KB
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; DAP: Disk Address Packet for INT 13h extensions
; Layout (16 bytes):
;  offset  size  field
;      0     1   size (0x10)
;      1     1   reserved (0)
;      2     2   count (sectors to read)
;      4     2   buffer offset
;      6     2   buffer segment
;      8     8   starting LBA (qword)
dap:
    db 0x10
    db 0x00
.count:    dw 0
.buf_off:  dw 0
.buf_seg:  dw 0
.lba_low:  dd 0
.lba_high: dd 0

; Variables
boot_drive    db 0
remaining     dw 0

; Pad loader to exactly 512 or 1024 bytes
%if ($-$$) < 510
    times 510-($-$$) db 0
    dw 0xaa55
%else
    times 1022-($-$$) db 0
    dw 0xaa55
%endif