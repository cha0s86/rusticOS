#!/bin/bash

# Debug test script for RusticOS
# Tests the OS and provides debugging information

echo "=== RusticOS Debug Test ==="
echo ""

# Check file sizes and contents
echo "File sizes:"
ls -la *.bin *.elf *.img
echo ""

echo "Bootloader size: $(wc -c < bootloader.bin) bytes"
echo "Loader size: $(wc -c < boot/loader.bin) bytes"
echo "Kernel size: $(wc -c < kernel.bin) bytes"
echo ""

# Check if files are properly aligned
echo "Checking file alignment:"
echo "Bootloader: $(($(wc -c < bootloader.bin) % 512)) bytes remainder"
echo "Loader: $(($(wc -c < boot/loader.bin) % 512)) bytes remainder"
echo "Kernel: $(($(wc -c < kernel.bin) % 512)) bytes remainder"
echo ""

# Check disk image layout
echo "Disk image sectors:"
echo "Sector 0: Bootloader (512 bytes)"
echo "Sector 1: Loader (538 bytes, spans 2 sectors)"
echo "Sector 2+: Kernel (978 bytes, spans 2 sectors)"
echo ""

# Test build
echo "Testing build..."
make clean
make

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build successful!"
    echo ""
    echo "Starting QEMU in debug mode..."
    echo "This will start QEMU with VNC display and GDB support"
    echo "Connect to VNC at 127.0.0.1:0 to see the display"
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Run in debug mode
    make debug
    
else
    echo "✗ Build failed!"
    exit 1
fi 