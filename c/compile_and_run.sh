#!/bin/bash
set -e

# Create output directory if it doesn't exist
mkdir -p ../output

# Compile with GDAL
echo "Compiling C NDVI calculator..."
gcc -Wall -O3 -march=native -o ndvi_calculator calculate_ndvi.c $(gdal-config --cflags) $(gdal-config --libs)

# Check if compilation was successful
if [ $? -eq 0 ]; then
  echo "Compilation successful. Running NDVI calculation..."
  
  # Run the program and time it
  time ./ndvi_calculator
  
  echo "NDVI calculation complete. Output saved to ../output/c.tif"
else
  echo "Compilation failed."
  exit 1
fi