; ============================================================================
; RusticOS - Second-Stage Loader (Real Mode -> Protected Mode)
; ----------------------------------------------------------------------------
; Purpose:
;   - Runs in 16-bit real mode at 0x10000 (loaded by the MBR boot sector)
;   - Enables A20
;   - Loads the 32-bit kernel from disk (from a fixed LBA) into memory
;   - Builds and loads a minimal GDT
;   - Enters 32-bit protected mode and halts (demo)
;
; Design Notes:
;   - ORG is 0x10000, so labels are linear addresses based on this origin.
;   - We use CHS reads via BIOS (INT 13h) and assume standard geometry:
;       * Sectors per track (SPT) = 63
;       * Heads per cylinder (HPC) = 16
;     These match the image layout used by the Makefile.
;   - Kernel is placed at fixed LBA 32 by the build (see Makefile).
;   - Disk reads are done sector-by-sector with retry and CHS carry logic.
;   - ES is advanced by paragraphs (0x20) each sector to avoid ES:BX wrap.
;
; Future Work (filesystem + language runtime):
;   - Replace fixed-LBA kernel load with filesystem lookup (e.g., "/boot/kernel.bin").
;   - Introduce a minimal FS driver (FAT12/16 or custom) to locate files by name.
;   - After kernel init, hand off to your language runtime (VM/JIT) as PID 1.
;
; Safety:
;   - DL (boot drive) is saved and restored for each BIOS call.
;   - BH is cleared for BIOS teletype INT 10h (AH=0x0E) to select page 0.
;   - CLD ensures string operations increment.
;
; ============================================================================

[org 0x10000]
[bits 16]

%include "boot/kernel_sectors.inc"   ; KERNEL_SECTORS (generated from kernel size)

; --- Disk geometry assumptions (matches Makefile image layout) ---
SPT equ 63                           ; Sectors per track
HPC equ 16                           ; Heads per cylinder

; --- Fixed disk layout ---
; LBA 0:     MBR (boot sector)
; LBA 1..31: Loader (we reserve space up to LBA 31)
; LBA 32.. : Kernel (written by Makefile)
KERNEL_LBA_START equ 32

; ============================================================================
; Entry Point (called by boot sector via far jump to 0x1000:0000)
; ============================================================================
loader_start:
    cli                             ; interrupts off during setup

    ; Set DS = CS (for position-independent data access), ES = DS
    push cs
    pop ds
    push ds
    pop es

    ; Real-mode stack in low memory (not used heavily here)
    xor  ax, ax
    mov  ss, ax
    mov  sp, 0x7c00
    cld                             ; ensure forward string ops

    xor  bh, bh                     ; BIOS teletype page 0
    mov  [boot_drive], dl           ; preserve BIOS boot drive

    ; Print: Loader started
    mov  si, loader_msg_start
    call print_string

    ; Enable A20 line via port 0x92 (Fast A20)
    in   al, 0x92
    or   al, 0x02
    out  0x92, al

    ; Print: Loading kernel
    mov  si, loader_msg_loading_kernel
    call print_string

    ; Destination for kernel image: 0x2000:0000 (128 KiB), grows upward
    mov  ax, 0x2000
    mov  es, ax
    xor  bx, bx                     ; keep BX=0 to avoid ES:BX wrap

    ; Compute kernel CHS from fixed LBA (KERNEL_LBA_START)
    mov  ax, KERNEL_LBA_START
    mov  [kernel_lba], ax

    ; --- Convert LBA -> CHS (for BIOS INT 13h CHS reads) ---
    ; c = LBA / (SPT * HPC)
    ; t = LBA % (SPT * HPC)
    ; h = t / SPT
    ; s = (t % SPT) + 1
    mov  bx, (SPT*HPC)              ; sectors per cylinder
    xor  dx, dx
    mov  ax, [kernel_lba]
    div  bx                         ; AX=cylinder, DX=remainder
    mov  [cur_cyl], al              ; (low 8 bits; small images only)

    mov  bx, SPT
    xor  ax, ax
    mov  ax, dx
    xor  dx, dx
    div  bx                         ; AX=head, DX=sector index (0..SPT-1)
    mov  [cur_head], al
    mov  al, dl
    inc  al                         ; sector number 1..SPT
    mov  [cur_sec], al

    ; Number of sectors to read for the kernel
    mov  di, KERNEL_SECTORS

.read_next_sector:
    cmp  di, 0
    jz   .all_read

    ; BIOS: Read 1 sector into ES:BX
    mov  ah, 0x02                   ; read
    mov  al, 1                      ; one sector per call
    mov  ch, [cur_cyl]
    mov  cl, [cur_sec]
    mov  dh, [cur_head]

    push bx
    mov  bp, 3                      ; retry count
.try_read:
    mov  dl, [boot_drive]
    int  0x13
    jnc  .ok

    ; On error: reset disk and retry
    mov  ah, 0x00
    mov  dl, [boot_drive]
    int  0x13
    dec  bp
    jnz  .try_read
    pop  bx
    jmp  disk_error
.ok:
    pop  bx

    ; Debug progress: '.' per sector
    mov  al, '.'
    mov  ah, 0x0e
    int  0x10

    ; Advance destination by one sector: ES += 0x20 paragraphs (512 bytes)
    ; Keep BX = 0 to avoid ES:BX overflow; this is simpler than adjusting BX.
    mov  ax, es
    add  ax, 0x20
    mov  es, ax

    ; Advance CHS -> next sector, with carry to head and cylinder
    inc  byte [cur_sec]
    cmp  byte [cur_sec], (SPT+1)    ; sectors are 1..SPT
    jl   .no_sec_carry
    mov  byte [cur_sec], 1
    inc  byte [cur_head]
    cmp  byte [cur_head], HPC       ; heads 0..HPC-1
    jl   .no_sec_carry
    mov  byte [cur_head], 0
    inc  byte [cur_cyl]
.no_sec_carry:

    dec  di
    jmp  .read_next_sector

.all_read:
    ; Print newline after progress dots
    mov  al, 13
    mov  ah, 0x0e
    int  0x10
    mov  al, 10
    mov  ah, 0x0e
    int  0x10

    ; Print: Kernel loaded
    mov  si, kernel_loaded_msg
    call print_string

    ; Optional debug: print first 4 bytes of kernel in hex
    mov  si, debug_kernel_msg
    call print_string
    mov  ax, 0x2000
    mov  es, ax
    mov  al, [es:0]
    call print_hex_byte
    mov  al, [es:1]
    call print_hex_byte
    mov  al, [es:2]
    call print_hex_byte
    mov  al, [es:3]
    call print_hex_byte
    mov  si, newline_msg
    call print_string

    ; ------------------------------------------------------------------------
    ; Enter Protected Mode
    ; ------------------------------------------------------------------------

    ; Load GDT (static descriptor; base is linear due to ORG 0x10000)
    ; GDT layout: null, flat code (0x08), flat data (0x10)
    lgdt [gdt_descriptor]

    ; Print: Switching to protected mode
    mov  si, loader_msg_pm_switch
    call print_string

    ; Set PE bit in CR0 (keep interrupts disabled)
    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    ; Far jump to load 32-bit code segment selector (0x08)
    ; This flushes the prefetch queue and commits the new CS.
    ; Emit exact bytes for 32-bit far jump to ensure correct encoding on all tools:
    ; 66 EA <offset32> <selector16>
    db 0x66, 0xEA
    dd protected_mode_entry
    dw 0x0008

; ============================================================================
; Helpers (16-bit real mode)
; ============================================================================

; print_string: prints ASCIIZ string at DS:SI using BIOS teletype
print_string:
    lodsb
    or   al, al
    jz   .done
    mov  ah, 0x0e
    int  0x10
    jmp  print_string
.done:
    ret

; print_hex_byte: prints AL as two lowercase hex digits and a trailing space
print_hex_byte:
    push ax
    shr  al, 4
    call .nibble
    pop  ax
    and  al, 0x0f
    call .nibble
    mov  al, ' '
    mov  ah, 0x0e
    int  0x10
    ret
.nibble:
    cmp  al, 10
    jl   .digit
    add  al, 'a' - 10
    jmp  .print
.digit:
    add  al, '0'
.print:
    mov  ah, 0x0e
    int  0x10
    ret

; ---------------------------------------------------------------------------
; Messages (ASCIIZ)
; ---------------------------------------------------------------------------
loader_msg_start          db 'Loader: started', 13, 10, 0
loader_msg_loading_kernel db 'Loader: loading kernel...', 13, 10, 0
kernel_loaded_msg         db 'Loader: kernel loaded', 13, 10, 0
loader_msg_pm_switch      db 'Loader: switching to protected mode', 13, 10, 0
debug_kernel_msg          db 'Loader: kernel bytes: ', 0
newline_msg               db 13, 10, 0

; ---------------------------------------------------------------------------
; State / Variables
; ---------------------------------------------------------------------------
boot_drive db 0                ; BIOS boot drive (DL)
cur_cyl    db 0                ; current cylinder
cur_head   db 0                ; current head
cur_sec    db 3                ; current sector (1..63)

pm_offset:
    dd 0        ; (unused placeholder)

jmp_target:
    dd 0        ; (unused placeholder)

pm_entry_addr:
    dd 0        ; (unused placeholder)

kernel_lba dw 0                ; LBA of kernel start

; ============================================================================
; GDT (flat 4GB code/data) and descriptor
; ============================================================================

align 8
;           63         47         31         15          0
;           +----------+----------+----------+-----------+
; Null    : |                0 (unused)                  |
; Code    : | base=0 limit=4GB gran=4K D=32 type=RX     |
; Data    : | base=0 limit=4GB gran=4K D=32 type=RW     |
;           +----------+----------+----------+-----------+

gdt_start:
    dq 0x0000000000000000         ; null descriptor
    dq 0x00cf9a000000ffff         ; code: base=0, limit=4GB, 32-bit, RX
    dq 0x00cf92000000ffff         ; data: base=0, limit=4GB, 32-bit, RW
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ============================================================================
; 32-bit Protected Mode Entry
; ============================================================================
[bits 32]
protected_mode_entry:
    ; We're now executing with PE=1; set up data segments and stack.
    ; Load flat data segments and set up a stack BEFORE any memory writes
    mov  ax, 0x10                ; data selector
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x90000            ; 576 KiB stack top

    ; Debug: show we reached PM (write to VGA text buffer)
    mov  eax, 0xb8000
    mov  word [eax], 0x1f50      ; 'P' white on blue

    mov  eax, 0xb8002
    mov  word [eax], 0x1f53      ; 'S' white on blue

    mov  eax, 0xb8004
    mov  word [eax], 0x1f54      ; 'T' white on blue

    ; Halt here (demo)
    ; Future: jump to kernel entry at 0x0010_0000 (per linker script), or
    ; call into a small loader that relocates/starts the kernel.
    cli
    hlt

; ============================================================================
; Error Handling
; ============================================================================
[bits 16]
disk_error:
    mov  si, disk_error_msg
    call print_string
.hang:
    hlt
    jmp  .hang

disk_error_msg db 'Loader: disk read error', 13, 10, 0
