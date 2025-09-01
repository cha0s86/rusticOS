; ============================================================================
; RusticOS - MBR Boot Sector (Stage 1)
; ----------------------------------------------------------------------------
; Purpose:
;   - Runs in 16-bit real mode loaded by BIOS at 0x7C00
;   - Loads the second-stage loader from disk (LBA 1..8) into 0x10000
;   - Transfers control to the loader via far jump to 0x1000:0000
;
; Disk Layout (as per Makefile):
;   LBA 0   : MBR boot sector (this file)
;   LBA 1-8 : Second-stage loader (max 8 sectors reserved)
;   LBA 32+ : Kernel (raw binary), loaded later by the loader
;
; Constraints:
;   - Must fit in 512 bytes with signature 0xAA55 at offset 510
;   - BIOS services available (INT 10h, INT 13h)
;   - Uses CHS read starting at cylinder=0, head=0, sector=2 for up to 8 sectors
;   - Assumes sector count does not cross a track boundary (safe for 8 sectors)
;
; Memory Map:
;   0x7C00 : Boot sector loaded by BIOS
;   0x10000: Loader load address (segment 0x1000, offset 0)
;
; Safety:
;   - Preserves BIOS-provided boot drive (DL)
;   - Clears DF (CLD) before string ops; sets BH=0 for teletype
;   - Includes simple retry loop on disk read
;
; Future Work (filesystem + custom language):
;   - Replace fixed CHS read with filesystem-aware loading (e.g., FAT12/FAT16 or custom)
;   - Consider switching to LBA (INT 13h extensions) for robustness
;   - Load /boot/loader.bin and kernel by name to support versions/modules
; ============================================================================
[org 0x7c00]
[bits 16]

start: ; Real-mode init: set segments/stack, save boot drive (DL)
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    cld
    xor bh, bh
    mov [boot_drive], dl

    ; Clear 512 bytes at loader destination (0x10000) - cosmetic
    mov ax, 0x1000
    mov es, ax
    xor di, di
    mov cx, 512/2
    xor ax, ax
    rep stosw

    ; Read loader sector(s) to 0x10000
    mov dl, [boot_drive]   ; Use BIOS-provided boot drive
    mov ax, 0x1000
    mov es, ax
    xor bx, bx             ; ES:BX -> 0x10000

    ; BIOS read: up to 8 sectors starting at CHS 0/0/2 (LBA 1)
    ; Note: will be replaced by FS-aware or LBA reads in future
    mov ah, 0x02           ; BIOS read sectors
    mov al, 8              ; Read up to 8 sectors for loader
    mov ch, 0              ; Cylinder 0
    mov cl, 2              ; Sector 2 (LBA 1)
    mov dh, 0              ; Head 0

    ; Retry loop (3 attempts): on error, reset disk and retry
    mov bp, 3
.read_try:
    mov dl, [boot_drive]
    int 0x13
    jnc .read_ok
    mov ah, 0x00           ; Reset disk
    mov dl, [boot_drive]
    int 0x13
    dec bp
    jnz .read_try
    jc  disk_error
.read_ok:

    mov si, msg_ok
    call print_string

    ; Far jump to loader (use far jmp to flush prefetch queue)
    jmp 0x1000:0x0000

print_string:    ; Print ASCIIZ string at DS:SI
    cld                    ; Ensure forward direction for LODSB
.print_loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp .print_loop
.done:
    ret

disk_error:
    mov si, msg_err
    call print_string
    cli
    hlt
    jmp $

boot_drive db 0                 ; BIOS boot drive (DL)
msg_ok db 'Stage-1: loader loaded', 13, 10, 0
msg_err db 'Stage-1: disk read error', 13, 10, 0

times 510-($-$$) db 0
 dw 0xaa55
