#!/bin/bash
set -e

# Set environment variables
export GDAL_DYNAMIC=YES
export GDAL_NUM_THREADS=ALL_CPUS
export GDAL_CACHEMAX=2048
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Build
echo "Compiling"
cargo build --release --bin whole-image-impl

echo "Running whole image implementation test..."
time target/release/whole-image-impl
