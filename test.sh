#!/bin/bash

# RusticOS Test Script
# Tests the build process and provides usage examples

echo "=== RusticOS Development Environment Test ==="
echo ""

# Check if required tools are available
echo "Checking required tools..."
if command -v nasm &> /dev/null; then
    echo "✓ NASM found: $(nasm --version | head -n1)"
else
    echo "✗ NASM not found. Please install it first."
    echo "  On Arch Linux: sudo pacman -S nasm"
    exit 1
fi

if command -v qemu-system-x86_64 &> /dev/null; then
    echo "✓ QEMU found: $(qemu-system-x86_64 --version | head -n1)"
else
    echo "✗ QEMU not found. Please install it first."
    echo "  On Arch Linux: sudo pacman -S qemu"
    exit 1
fi

echo "✓ Make found: $(make --version | head -n1)"
echo "✓ dd found: $(dd --version | head -n1)"
echo ""

# Clean and build
echo "Building RusticOS..."
make clean
make

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build successful!"
    echo ""
    echo "Generated files:"
    ls -la *.bin *.img
    echo ""
    echo "=== Usage Examples ==="
    echo ""
    echo "1. Run in QEMU (default display):"
    echo "   make run"
    echo ""
    echo "2. Run with VNC display (connect with VNC client to 127.0.0.1:0):"
    echo "   make run-vnc"
    echo ""
    echo "3. Run with curses display (if available):"
    echo "   make run-curses"
    echo ""
    echo "4. Run in debug mode:"
    echo "   make debug"
    echo ""
    echo "5. Clean build files:"
    echo "   make clean"
    echo ""
    echo "6. Show all available targets:"
    echo "   make help"
    echo ""
    echo "=== Quick Test ==="
    echo "Running a quick test in QEMU (will exit after 5 seconds)..."
    echo "You should see the bootloader and kernel messages."
    echo ""
    
    # Run a quick test
    timeout 5s make run || echo "QEMU test completed."
    
else
    echo "✗ Build failed!"
    exit 1
fi 