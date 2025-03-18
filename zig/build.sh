#!/bin/bash
set -e

# Build with optimal settings
echo "Building SIMD-optimized Zig implementation..."
zig build-exe src/main.zig -lc -lgdal -I/usr/include/gdal -O ReleaseFast -fstrip -mcpu=native