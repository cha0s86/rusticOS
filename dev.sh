#!/bin/bash

# RusticOS Development Script
# Automatically rebuilds and runs the OS when files change

echo "RusticOS Development Mode"
echo "Watching for changes in .asm files..."
echo "Press Ctrl+C to exit"
echo ""

# Function to build and run
build_and_run() {
    echo "Changes detected, rebuilding..."
    make clean
    make
    if [ $? -eq 0 ]; then
        echo "Build successful! Starting QEMU..."
        timeout 10s make run || echo "QEMU stopped or timed out"
    else
        echo "Build failed!"
    fi
    echo ""
    echo "Watching for changes..."
}

# Check if inotify-tools is available
if command -v inotifywait &> /dev/null; then
    echo "Using inotify for file watching..."
    while true; do
        inotifywait -q -e modify *.asm Makefile
        build_and_run
    done
else
    echo "inotify-tools not found. Using manual mode."
    echo "Press Enter to rebuild and run, or Ctrl+C to exit"
    while true; do
        read -r
        build_and_run
    done
fi 