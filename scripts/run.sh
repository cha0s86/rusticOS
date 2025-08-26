#!/usr/bin/env bash
set -euo pipefail

mode="${1:-headless}" # headless|vnc|curses|debug

case "$mode" in
  headless)
    make run-headless ;;
  vnc)
    make run ;;
  curses)
    make run-curses ;;
  debug)
    make debug ;;
  *)
    echo "Usage: $0 [headless|vnc|curses|debug]" >&2
    exit 1 ;;
 esac 