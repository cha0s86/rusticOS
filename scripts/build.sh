#!/usr/bin/env bash
set -euo pipefail

# Build all by default, or pass a target
if [[ $# -gt 0 ]]; then
  make "$@"
else
  make all
fi 