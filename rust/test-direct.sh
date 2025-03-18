#!/bin/bash
set -e

# Set environment variables
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Save the direct implementation
cat src/direct-gdal-impl.rs > src/main.rs

# Clean up 
echo "Cleaning up"
cargo clean

# Build
echo "Compiling"
cargo build --release --quiet

echo "Running direct GDAL implementation test..."
time ./target/release/geo-spectra-calc

# Clean up
rm src/main.rs
touch src/main.rs