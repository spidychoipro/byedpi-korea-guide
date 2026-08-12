#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo "$DIR/ciadpi" \
  -i 127.0.0.1 \
  -p 1080 \
  --disorder 1 \
  --auto=torst \
  --tlsrec 1+s
