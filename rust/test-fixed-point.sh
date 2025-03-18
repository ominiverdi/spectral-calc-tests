#!/bin/bash
set -e

# Set environment variables
export GDAL_DYNAMIC=YES
export GDAL_NUM_THREADS=ALL_CPUS
export GDAL_CACHEMAX=2048
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Load the implementation
cat src/fixed-point-impl.rs > src/main.rs

# Clean up 
echo "Cleaning up"
cargo clean

# Build
echo "Compiling"
cargo build --release --quiet

echo "Running fixed-point implementation test..."
time ./target/release/geo-spectra-calc

# Check file sizes and compare
echo "File size comparison:"
ls -lh ../output/rust_whole_image.tif ../output/rust_fixed_point.tif

# Clean up
rm src/main.rs
touch src/main.rs