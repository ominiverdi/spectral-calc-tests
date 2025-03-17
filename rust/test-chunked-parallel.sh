#!/bin/bash
set -e

# Set GDAL environment variable
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES
export RUSTFLAGS="-C target-cpu=native -C opt-level=3"

# Save the high-performance implementation
cp src/main.rs src/main.rs.bak
cat src/chunked-parallel-impl.rs > src/main.rs

# Rebuild
cargo clean
cargo build --release

echo "Running high-performance test..."
time ./target/release/geo-spectra-calc

# Restore original implementation
cp src/main.rs.bak src/main.rs