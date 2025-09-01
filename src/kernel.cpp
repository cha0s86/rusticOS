/*
 * RusticOS Kernel (C++)
 * ---------------------
 * Purpose:
 *   - Entry point for the 32-bit protected-mode kernel (called from crt0.s)
 *   - Provides a basic text-mode terminal UI and simple keyboard input loop
 *
 * Environment:
 *   - Executing in 32-bit protected mode with flat segments
 *   - Stack initialized to 0x90000 by crt0.s
 *   - VGA text buffer available at 0xB8000
 *
 * Build/Link:
 *   - Linked to 1 MiB (0x0010_0000) by linker.ld (ENTRY(_start))
 *   - Started from assembly stub in src/crt0.s which sets up segments and calls kernel_main()
 *
 * Notes:
 *   - This kernel is deliberately simple and single-threaded.
 *   - No dynamic memory allocator is implemented; new/delete are stubbed.
 *   - Keyboard input is polled (no interrupts) for simplicity.
 */

#include <stdint.h>
#include <cstddef>
#include "terminal.h"
#include "keyboard.h"
//
// Roadmap notes (for future development):
// - File system: Add a simple filesystem (e.g., FAT12/FAT16 or a custom FS) so the loader can locate kernel and user programs by name instead of fixed LBAs.
// - Language runtime: Plan a small bytecode VM or JIT loader to run your own language atop the kernel. Expose a syscalls layer for I/O, timers, and memory.
// - Boot flow: switch loader to read kernel from FS; kernel mounts root FS, then launches the language runtime entrypoint.
// - Debugging: introduce a serial log and basic panic() with error codes.

// ----------------------------------------------------------------------------
// Port I/O helper (read byte from I/O port)
// ----------------------------------------------------------------------------
static inline uint8_t __inb(uint16_t port) {
    uint8_t value;
    __asm__ __volatile__("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

// ----------------------------------------------------------------------------
// C++ runtime support: pure virtual call handler
// ----------------------------------------------------------------------------
extern "C" void __cxa_pure_virtual() {
    // Pure virtual function called - this indicates a programming error.
    // Halt the CPU forever to avoid undefined behavior.
    for (;;) {
        __asm__ __volatile__("hlt");
    }
}

// ----------------------------------------------------------------------------
// Minimal operator new/delete stubs
// ----------------------------------------------------------------------------
// These are placeholders to satisfy the C++ runtime. A real kernel would
// implement a memory allocator and return usable pointers.
void* operator new(std::size_t /*size*/) {
    // Return a dummy non-null pointer as per C++ requirement.
    return reinterpret_cast<void*>(0x100000);
}

void operator delete(void* ptr) noexcept {
    (void)ptr; // no-op
}

void* operator new[](std::size_t /*size*/) {
    return reinterpret_cast<void*>(0x100000);
}

void operator delete[](void* ptr) noexcept {
    (void)ptr; // no-op
}

// ----------------------------------------------------------------------------
// Simple, polled keyboard input (no interrupts)
// ----------------------------------------------------------------------------
// Returns scan code if a key is available, otherwise returns 0.
static uint8_t poll_keyboard() {
    // Status register at port 0x64: bit 0 set => output buffer full
    uint8_t status = __inb(0x64);
    if (status & 0x01) {
        return __inb(0x60); // Read scan code
    }
    return 0;
}

// ----------------------------------------------------------------------------
// Built-in help topic displayed at boot
// ----------------------------------------------------------------------------
static void show_help() {
    terminal.setColor(LIGHT_GREY, BLACK);
    terminal.write("Help:\n");
    terminal.write("- Type to echo characters. Backspace deletes. Enter starts a new line.\n");
    terminal.write("- ESC exits the demo loop and halts the CPU.\n");
    terminal.write("- Future: a filesystem and custom language runtime will run here.\n\n");
}

// ----------------------------------------------------------------------------
// Kernel entry point (called by crt0.s)
// ----------------------------------------------------------------------------
extern "C" void kernel_main() {
    // Initialize terminal to a known state
    terminal.clear();
    terminal.setColor(LIGHT_GREEN, BLACK);

    // Welcome banner
    terminal.write("Welcome to RusticOS 32-bit Enhanced!\n");
    terminal.write("Running in protected mode with C++ support\n\n");

    // Basic system info
    terminal.setColor(LIGHT_CYAN, BLACK);
    terminal.write("System Information:\n");
    terminal.write("- Architecture: x86 (32-bit protected mode)\n");
    terminal.write("- VGA: Text mode 80x25 with cursor support\n");
    terminal.write("- Stack: 0x90000\n");
    terminal.write("- Kernel: Linked at 1 MiB (0x0010_0000)\n");
    terminal.write("- Features: Keyboard input, cursor movement, scrolling\n\n");

    // Status line and quick help
    terminal.setColor(LIGHT_BROWN, BLACK);
    terminal.write("Status: Ready. Press ESC to exit demo loop.\n\n");
    show_help();

    // Draw a simple UI box
    terminal.setColor(LIGHT_BLUE, BLACK);
    terminal.drawBox(0, 15, 79, 24, '#');
    terminal.writeAt("Interactive Terminal - Type here:", 2, 16);

    // Enable simple input mode and set cursor position
    terminal.enableInput(true);
    terminal.setCursor(2, 17);

    // Prompt
    terminal.setColor(WHITE, BLACK);
    terminal.write("> ");

    uint8_t last_key = 0;
    uint16_t input_line = 0; // Reserved for future line counter (unused)

    // Main kernel loop: poll keyboard and echo simple ASCII
    for (;;) {
        // Poll the keyboard controller for a scan code
        uint8_t key = poll_keyboard();

        // Very naive de-bounce: only react to changes
        if (key != 0 && key != last_key) {
            last_key = key;

            // Handle a few special keys directly by scan code
            if (key == 0x01) { // ESC key
                terminal.setColor(LIGHT_RED, BLACK);
                terminal.write("\nExiting...\n");
                break;
            }

            // Convert a limited range of scan codes to ASCII (very simplified)
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

            // Echo the ASCII and handle line input behavior
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

        // Halt CPU until next event; in a real OS, this would return on IRQs
        __asm__ __volatile__("hlt");

        // Future work: scheduler, IRQ handling, syscalls, memory management, etc.
    }

    // Graceful shutdown path (we never return to the loader)
    terminal.setColor(LIGHT_GREEN, BLACK);
    terminal.write("\nKernel shutdown complete.\n");

    for (;;) {
        __asm__ __volatile__("hlt");
    }
}
