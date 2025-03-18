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
cat src/whole-image-impl.rs > src/main.rs

# Clean up 
echo "Cleaning up"
cargo clean

# Build
echo "Compiling"
cargo build --release --quiet

echo "Running whole image implementation test..."
time ./target/release/geo-spectra-calc

# Clean up
rm src/main.rs
touch src/main.rs