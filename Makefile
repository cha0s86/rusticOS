# RusticOS Development Environment Makefile
# Supports both 16-bit bootloader and 32-bit C++ kernel

# Compiler and assembler
NASM = nasm
QEMU = qemu-system-x86_64

# Use system GCC with 32-bit support
CC = gcc
CXX = g++
LD = ld
OBJCOPY = objcopy

# Flags
NASM_FLAGS = -f bin
# QEMU flags for floppy disk
QEMU_FLAGS = -machine pc -boot a -drive file=$(OS_IMAGE),if=floppy,format=raw

# C++ compilation flags
CXXFLAGS = -m32 -ffreestanding -fno-exceptions -fno-rtti -fno-stack-protector -fno-pie -O2 -Wall -Wextra -std=c++11
CFLAGS = -m32 -ffreestanding -fno-stack-protector -fno-pie -O2 -Wall -Wextra -std=c99
LDFLAGS = -nostdlib -T linker.ld -melf_i386

# Files
BOOTLOADER = bootloader.bin
LOADER = boot/loader.bin
KERNEL_ELF = kernel.elf
KERNEL_BIN = kernel.bin
OS_IMAGE = os.img

# Directories
BUILD_DIR = build
SRC_DIR = src
BOOT_DIR = boot

# Kernel sectors
KERNEL_SECTORS := $(shell echo $$((($(shell stat -c%s $(KERNEL_BIN)) + 511) / 512)))

# Default target
all: $(OS_IMAGE)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build the bootloader
$(BOOTLOADER): bootloader.asm
	$(NASM) $(NASM_FLAGS) -o $@ $<

# Build the second-stage loader
$(LOADER): $(BOOT_DIR)/loader.asm boot/kernel_sectors.inc
	$(NASM) $(NASM_FLAGS) -o $@ $<

# Build C++ startup code
$(BUILD_DIR)/crt0.o: $(SRC_DIR)/crt0.s | $(BUILD_DIR)
	$(CC) -c $(CFLAGS) $< -o $@

# Build C++ kernel
$(BUILD_DIR)/kernel.o: $(SRC_DIR)/kernel.cpp | $(BUILD_DIR)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Build keyboard driver
$(BUILD_DIR)/keyboard.o: $(SRC_DIR)/keyboard.cpp | $(BUILD_DIR)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Build terminal
$(BUILD_DIR)/terminal.o: $(SRC_DIR)/terminal.cpp | $(BUILD_DIR)
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Link the kernel
$(KERNEL_ELF): $(BUILD_DIR)/crt0.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/terminal.o linker.ld
	$(LD) $(LDFLAGS) -o $@ $(BUILD_DIR)/crt0.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/terminal.o

# Convert ELF to binary for disk image
$(KERNEL_BIN): $(BUILD_DIR)/crt0.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/terminal.o linker.ld
	$(LD) $(LDFLAGS) --oformat binary -o $@ $(BUILD_DIR)/crt0.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/terminal.o

# Generate kernel sectors include file
boot/kernel_sectors.inc: $(KERNEL_BIN)
	echo "KERNEL_SECTORS equ $(KERNEL_SECTORS)" > $@

# Create OS image
$(OS_IMAGE): $(BOOTLOADER) $(LOADER) $(KERNEL_BIN)
	@echo "Creating OS image..."
	# Create a 10MB hard disk image
	dd if=/dev/zero of=$(OS_IMAGE) bs=1M count=10 2>/dev/null
	# Write bootloader to sector 0 (MBR)
	dd if=$(BOOTLOADER) of=$(OS_IMAGE) bs=512 seek=0 count=1 conv=notrunc 2>/dev/null
	# Write loader to sector 1
	dd if=$(LOADER) of=$(OS_IMAGE) bs=512 seek=1 count=1 conv=notrunc 2>/dev/null
	# Write kernel to sector 2 (multiple sectors)
	dd if=$(KERNEL_BIN) of=$(OS_IMAGE) bs=512 seek=2 count=$(KERNEL_SECTORS) conv=notrunc 2>/dev/null
	@echo "OS image created: $(OS_IMAGE)"

# Run the OS in QEMU with VNC display (default)
run: $(OS_IMAGE)
	$(QEMU) $(QEMU_FLAGS) -display vnc=127.0.0.1:0

# Run in QEMU headless (no display)
run-headless: $(OS_IMAGE)
	$(QEMU) $(QEMU_FLAGS) -nographic

# Run in QEMU with curses display (if available)
run-curses: $(OS_IMAGE)
	$(QEMU) $(QEMU_FLAGS) -display curses

# Debug mode with QEMU
debug: $(OS_IMAGE)
	$(QEMU) $(QEMU_FLAGS) -display vnc=127.0.0.1:0 -s -S

# Build only the kernel (for development)
kernel: $(KERNEL_ELF)

# Build only the boot components
boot: $(BOOTLOADER) $(LOADER)

# Clean build files
clean:
	rm -f $(BOOTLOADER) $(LOADER) $(KERNEL_ELF) $(KERNEL_BIN) $(OS_IMAGE)
	rm -rf $(BUILD_DIR)

# Show help
help:
	@echo "Available targets:"
	@echo "  all         - Build the complete OS image"
	@echo "  boot        - Build only bootloader and loader"
	@echo "  kernel      - Build only the 32-bit kernel"
	@echo "  run         - Build and run with VNC display (127.0.0.1:0)"
	@echo "  run-headless- Build and run without display (headless)"
	@echo "  run-curses  - Build and run with curses display"
	@echo "  debug       - Build and run in QEMU debug mode"
	@echo "  clean       - Remove build files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "To view VNC output:"
	@echo "  Install a VNC client and connect to 127.0.0.1:0"
	@echo "  Or use: vncviewer 127.0.0.1:0"
	@echo ""
	@echo "System GCC with 32-bit support is used for compilation"

.PHONY: all boot kernel run run-headless run-curses debug clean help