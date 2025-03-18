#!/bin/bash
set -e

# Set environment variables for GDAL
export GDAL_NUM_THREADS=ALL_CPUS
export GDAL_CACHEMAX=2048

# Run the program
# echo "Running NDVI calculation..."
./main