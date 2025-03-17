#!/bin/bash
set -e

# Save the direct implementation
cp src/main.rs src/main.rs.bak
cat src/direct-gdal-impl.rs > src/main.rs

# Update Cargo.toml to include libc dependency
if ! grep -q "libc" Cargo.toml; then
    sed -i '/rayon/a libc = "0.2"' Cargo.toml
fi

# Build with simplified flags
export RUSTFLAGS="-C target-cpu=native -C opt-level=3"

# Clean and rebuild
cargo clean
cargo build --release

echo "Running direct GDAL implementation test..."
time ./target/release/geo-spectra-calc

# Restore original implementation
cp src/main.rs.bak src/main.rs