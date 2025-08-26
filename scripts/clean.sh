#!/usr/bin/env bash
set -euo pipefail

# Clean build artifacts and generated files
rm -rf out build qemu.log
 
# Preserve scripts/, docs/, config/, tools/
echo "Clean complete." 