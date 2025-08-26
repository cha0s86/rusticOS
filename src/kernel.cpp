#include <stdint.h>
#include <cstddef>
#include "terminal.h"
#include "keyboard.h"

// I/O functions for keyboard polling
static inline uint8_t __inb(uint16_t port) {
    uint8_t value;
    __asm__ __volatile__("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

// C++ runtime support functions
extern "C" void __cxa_pure_virtual() {
    // Pure virtual function called - this shouldn't happen
    for (;;) {
        __asm__ __volatile__("hlt");
    }
}

// Memory management stubs (minimal)
void* operator new(std::size_t /*size*/) {
    // Simple stub - no actual memory allocation
    // Standard requires non-NULL unless throw(), so return a dummy pointer
    return reinterpret_cast<void*>(0x100000); // or any non-null dummy address
}

void operator delete(void* ptr) noexcept {
    (void)ptr; // Suppress unused parameter warning
}

void* operator new[](std::size_t /*size*/) {
    // Simple stub - no actual memory allocation
    return reinterpret_cast<void*>(0x100000); // or any non-null dummy address
}

void operator delete[](void* ptr) noexcept {
    (void)ptr;
}

// Simple keyboard polling (in a real OS, you'd use interrupts)
uint8_t poll_keyboard() {
    // Check if there's a key available
    uint8_t status = __inb(0x64);
    if (status & 0x01) {
        return __inb(0x60);
    }
    return 0;
}

// Kernel main function
extern "C" void kernel_main() {
    // Initialize terminal
    terminal.clear();
    terminal.setColor(LIGHT_GREEN, BLACK);
    
    // Welcome message
    terminal.write("Welcome to RusticOS 32-bit Enhanced!\n");
    terminal.write("Running in protected mode with C++ support\n\n");
    
    // System info
    terminal.setColor(LIGHT_CYAN, BLACK);
    terminal.write("System Information:\n");
    terminal.write("- Architecture: x86 (32-bit protected mode)\n");
    terminal.write("- VGA: Text mode 80x25 with cursor support\n");
    terminal.write("- Stack: 0x90000\n");
    terminal.write("- Kernel: Loaded at 1 MiB\n");
    terminal.write("- Features: Keyboard input, cursor movement, scrolling\n\n");
    
    // Status
    terminal.setColor(LIGHT_BROWN, BLACK);
    terminal.write("Status: Ready\n");
    terminal.write("Press keys to test input (ESC to exit)\n\n");
    
    // Draw a simple UI box
    terminal.setColor(LIGHT_BLUE, BLACK);
    terminal.drawBox(0, 15, 79, 24, '#');
    terminal.writeAt("Interactive Terminal - Type here:", 2, 16);
    
    // Enable input mode
    terminal.enableInput(true);
    terminal.setCursor(2, 17);
    
    // Main kernel loop with keyboard input
    terminal.setColor(WHITE, BLACK);
    terminal.write("> ");
    
    uint8_t last_key = 0;
    uint16_t input_line = 0;
    
    for (;;) {
        // Poll keyboard
        uint8_t key = poll_keyboard();
        
        if (key != 0 && key != last_key) {
            last_key = key;
            
            // Handle special keys
            if (key == 0x01) { // ESC key
                terminal.setColor(LIGHT_RED, BLACK);
                terminal.write("\nExiting...\n");
                break;
            }
            
            // Convert scan code to ASCII (simplified)
            char ascii = 0;
            if (key >= 0x02 && key <= 0x0D) {
                const char* chars = "1234567890-=";
                ascii = chars[key - 0x02];
            } else if (key >= 0x10 && key <= 0x1B) {
                const char* chars = "qwertyuiop[]";
                ascii = chars[key - 0x10];
            } else if (key >= 0x1E && key <= 0x28) {
                const char* chars = "asdfghjkl;'";
                ascii = chars[key - 0x1E];
            } else if (key >= 0x2C && key <= 0x35) {
                const char* chars = "zxcvbnm,./";
                ascii = chars[key - 0x2C];
            } else if (key == 0x39) {
                ascii = ' ';
            } else if (key == 0x1C) { // Enter
                ascii = '\n';
            } else if (key == 0x0E) { // Backspace
                ascii = '\b';
            }
            
            if (ascii != 0) {
                if (ascii == '\n') {
                    terminal.write("\n> ");
                    input_line++;
                } else if (ascii == '\b') {
                    terminal.moveCursor(-1, 0);
                    terminal.putChar(' ');
                    terminal.moveCursor(-1, 0);
                } else {
                    terminal.putChar(ascii);
                }
            }
        }
        
        // Halt CPU to save power
        __asm__ __volatile__("hlt");
        
        // In a real OS, this would handle:
        // - Process scheduling
        // - Interrupt handling
        // - System calls
        // - Memory management
        // - Device I/O
    }
    
    // Final message
    terminal.setColor(LIGHT_GREEN, BLACK);
    terminal.write("\nKernel shutdown complete.\n");
    
    // Halt forever
    for (;;) {
        __asm__ __volatile__("hlt");
    }
}