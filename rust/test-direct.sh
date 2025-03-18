#!/bin/bash
set -e

# Set environment variables
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Build
echo "Compiling"
cargo build --release --bin chunked-parallel-impl

echo "Running direct GDAL implementation test..."
time target/release/direct-gdal-impl
