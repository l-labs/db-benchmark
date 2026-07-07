#!/bin/bash
set -e

# L ships as prebuilt, dependency-free release binaries (Linux x86-64
# AVX2 / AVX-512 and macOS arm64); there is nothing to compile here.
# Obtain the binary for your platform from an L release, `chmod +x` it,
# and either place it on PATH as `l` or point $L_BIN at it.
# The release tag this solution was validated against is in l/VERSION.

BIN="${L_BIN:-$(command -v l || true)}"
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "l binary not found."
  echo "Download an L release binary for your platform, chmod +x it,"
  echo "then place it on PATH as 'l' or set L_BIN to its path."
  exit 1
fi
echo "using l at: $BIN"

./l/ver-l.sh
