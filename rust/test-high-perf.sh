#!/bin/bash

# Set GDAL environment variable
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=fat"

# Save the high-performance implementation
cp src/main.rs src/main.rs.bak
cat high-perf-impl.rs > src/main.rs

# Rebuild with aggressive optimizations
cargo clean
cargo build --release

echo "Running high-performance test..."
time ./target/release/ndvi_calculator

# Restore original implementation if needed
# cp src/main.rs.bak src/main.rs