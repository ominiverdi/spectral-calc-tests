#!/bin/bash
set -e

# Set GDAL environment variables
export GDAL_DYNAMIC=YES
export GDAL_NUM_THREADS=ALL_CPUS
export GDAL_CACHEMAX=2048

export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu

# Save the implementation
cp -f src/main.rs src/main.rs.bak
cat src/whole-image-impl.rs > src/main.rs

# Build
RUSTFLAGS="-C target-cpu=native -C opt-level=3" cargo build --release

echo "Running whole image implementation test..."
time ./target/release/geo-spectra-calc

# Restore original implementation if needed
cp -f src/main.rs.bak src/main.rs