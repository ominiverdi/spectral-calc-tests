#!/bin/bash
set -e

# Set environment variables for GDAL
export GDAL_NUM_THREADS=ALL_CPUS
export GDAL_CACHEMAX=2048

# Clean up existing files
rm -f ./main

# Build with optimal settings
echo "Building SIMD-optimized Zig implementation..."
zig build-exe src/main.zig -lc -lgdal -I/usr/include/gdal -O ReleaseFast -fstrip -mcpu=native

# Run the program
echo "Running NDVI calculation..."
time ./main

# Check output file
echo "File size and generation time:"
ls -lh ../output/zig_simd.tif