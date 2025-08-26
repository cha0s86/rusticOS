[org 0x0000]
[bits 16]

loader_start:
    ; Simple test - just print a message and halt
    mov si, loader_test_msg
    call print_string
    
    ; Halt the system
    cli
    hlt

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

loader_test_msg db 'LOADER: I am running!', 13, 10, 0

; Pad loader to 512 bytes
times 512-($-$$) db 0