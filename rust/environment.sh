# First, run gdal-config to see the correct flags
gdal-config --libs

# Then set these environment variables
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES


export GDAL_DYNAMIC=YES
