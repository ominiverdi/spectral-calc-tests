#!/bin/bash
set -e

# Set environment variables
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Build
echo "Compiling"
cargo build --release --bin chunked-parallel-impl

echo "Running direct GDAL implementation test..."
time target/release/direct-gdal-impl
