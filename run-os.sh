#!/bin/bash

# RusticOS Runner Script
# Runs the OS and helps connect to VNC display

echo "Starting RusticOS in QEMU with VNC display..."
echo "VNC server will be available at 127.0.0.1:0"
echo ""

# Check if we have a VNC viewer available
VNC_VIEWER=""
if command -v vncviewer &> /dev/null; then
    VNC_VIEWER="vncviewer"
elif command -v vinagre &> /dev/null; then
    VNC_VIEWER="vinagre"
elif command -v remmina &> /dev/null; then
    VNC_VIEWER="remmina"
fi

# Build the OS first
echo "Building RusticOS..."
make

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful! Starting QEMU..."
    echo ""
    
    if [ -n "$VNC_VIEWER" ]; then
        echo "Auto-opening VNC viewer in 3 seconds..."
        echo "You can also manually connect to 127.0.0.1:0"
        echo ""
        
        # Start QEMU in background
        make run &
        QEMU_PID=$!
        
        # Wait a moment for QEMU to start
        sleep 3
        
        # Open VNC viewer
        echo "Opening VNC viewer..."
        $VNC_VIEWER 127.0.0.1:0 &
        
        echo ""
        echo "QEMU is running with PID: $QEMU_PID"
        echo "Press Ctrl+C to stop QEMU"
        echo ""
        
        # Wait for QEMU to finish
        wait $QEMU_PID
        
    else
        echo "No VNC viewer found. Starting QEMU..."
        echo "Install a VNC client to view the display:"
        echo "  - tigervnc (vncviewer)"
        echo "  - vinagre"
        echo "  - remmina"
        echo ""
        echo "Then connect to 127.0.0.1:0"
        echo ""
        
        make run
    fi
    
else
    echo "Build failed!"
    exit 1
fi 