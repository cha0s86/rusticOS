#!/bin/bash

# RusticOS Build Script
# This script automates the build and run process

echo "Building RusticOS..."

# Check if NASM is installed
if ! command -v nasm &> /dev/null; then
    echo "Error: NASM is not installed. Please install NASM first."
    echo "On Arch Linux: sudo pacman -S nasm"
    echo "On Ubuntu/Debian: sudo apt install nasm"
    exit 1
fi

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "Error: QEMU is not installed. Please install QEMU first."
    echo "On Arch Linux: sudo pacman -S qemu"
    echo "On Ubuntu/Debian: sudo apt install qemu-system-x86"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Build the OS
echo "Building bootloader and kernel..."
make

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo ""
    echo "Starting RusticOS in QEMU..."
    echo "Press Ctrl+C to exit QEMU"
    echo ""
    
    # Run the OS
    make run
else
    echo "Build failed!"
    exit 1
fi 