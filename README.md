# RusticOS - Simple x86_64 Operating System

A minimal operating system development environment built with NASM and QEMU for learning OS development concepts.

## Features

- **Bootloader**: Simple BIOS bootloader that loads the kernel
- **Kernel**: Basic kernel with text output capabilities
- **Build System**: Makefile and build scripts for easy development
- **Emulation**: QEMU integration for testing without real hardware

## Prerequisites

### Required Software

1. **NASM** (Netwide Assembler) - for compiling assembly code
2. **QEMU** - for emulating the x86_64 system
3. **Make** - for building the project
4. **dd** - for creating disk images (usually pre-installed on Linux)

### Installation

#### Arch Linux
```bash
sudo pacman -S nasm qemu make
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install nasm qemu-system-x86 make
```

#### macOS
```bash
brew install nasm qemu make
```

## Project Structure

```
rusticOS/
├── bootloader.asm    # BIOS bootloader (first sector)
├── kernel.asm        # Simple kernel (loaded by bootloader)
├── Makefile          # Build configuration
├── build.sh          # Automated build script
└── README.md         # This file
```

## Quick Start

### Method 1: Using the build script (Recommended)
```bash
chmod +x build.sh
./build.sh
```

### Method 2: Using Make directly
```bash
# Build the OS
make

# Run in QEMU
make run

# Run in debug mode
make debug

# Clean build files
make clean
```

## How It Works

### 1. Bootloader (bootloader.asm)
- Loaded by BIOS at memory address `0x7c00`
- Runs in 16-bit real mode
- Loads the kernel from disk sector 1
- Jumps to the kernel at address `0x8000`

### 2. Kernel (kernel.asm)
- Loaded by the bootloader
- Provides basic OS functionality
- Displays welcome messages
- Enters an infinite loop (simplified OS behavior)

### 3. Build Process
1. NASM compiles assembly files to binary format
2. `dd` creates a disk image
3. Bootloader and kernel are written to the image
4. QEMU boots from the image

## Development

### Adding Features

#### Extending the Kernel
- Modify `kernel.asm` to add new functionality
- Add new assembly routines
- Implement system calls or interrupts

#### Adding More Assembly Files
1. Create new `.asm` files
2. Add them to the Makefile
3. Update the build process

### Debugging

#### QEMU Debug Mode
```bash
make debug
```
This starts QEMU in debug mode where you can:
- Use GDB to debug the running system
- Set breakpoints
- Inspect memory and registers

#### Common Issues
- **"Permission denied"**: Make sure `build.sh` is executable (`chmod +x build.sh`)
- **"Command not found"**: Install required packages (NASM, QEMU)
- **Build errors**: Check assembly syntax and Makefile dependencies

## Learning Resources

- [NASM Documentation](https://www.nasm.us/doc/)
- [QEMU Documentation](https://qemu.readthedocs.io/)
- [OSDev Wiki](https://wiki.osdev.org/)
- [x86 Assembly Guide](https://www.cs.virginia.edu/~evans/cs216/guides/x86.html)

## Next Steps

This is a basic foundation. Consider adding:
- Memory management
- Process scheduling
- File system
- Device drivers
- User interface
- Networking stack

## License

This project is open source and available under the MIT License.

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve this OS development environment. 