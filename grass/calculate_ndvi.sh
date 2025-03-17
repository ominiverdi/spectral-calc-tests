#!/bin/bash
set -e

# Create output directory
mkdir -p ../output

# Setup GRASS location in temporary directory
LOCATION_PATH=$(mktemp -d)
echo "Creating temporary GRASS location at $LOCATION_PATH"

# Start timing the entire process
TOTAL_START=$(date +%s.%N)

# Create GRASS location
grass -c epsg:32633 $LOCATION_PATH/grassdata/sentinel2_loc -e

# Start GRASS session
grass $LOCATION_PATH/grassdata/sentinel2_loc/PERMANENT --exec bash << 'EOF'

# Start timing the complete operation
START=$(date +%s.%N)

# Import bands
echo "Importing NIR and RED bands..."
r.import input=../data/T33TTG_20250305T100029_B08_10m.jp2 output=nir_band
r.import input=../data/T33TTG_20250305T100029_B04_10m.jp2 output=red_band

# Apply scale factor and calculate NDVI in one step
echo "Calculating NDVI..."
r.mapcalc expression="ndvi = if((nir_band-1000)/10000.0 + (red_band-1000)/10000.0 > 0, ((nir_band-1000)/10000.0 - (red_band-1000)/10000.0)/((nir_band-1000)/10000.0 + (red_band-1000)/10000.0), null())" --overwrite

# Export result
echo "Exporting result..."
r.out.gdal input=ndvi output=../output/grass_ndvi.tif format=GTiff createopt="COMPRESS=DEFLATE,TILED=YES" --overwrite

END=$(date +%s.%N)
RUNTIME=$(echo "$END - $START" | bc)
echo "GRASS complete processing time: $RUNTIME seconds"

EOF

TOTAL_END=$(date +%s.%N)
TOTAL_RUNTIME=$(echo "$TOTAL_END - $TOTAL_START" | bc)
echo "Total script execution time: $TOTAL_RUNTIME seconds"

# Clean up
echo "Cleaning up temporary files..."
rm -rf $LOCATION_PATH

echo "GRASS GIS NDVI calculation complete. Output saved to ../output/grass_ndvi.tif"