# Define path variables for readability
# NIR_BAND="../data/T33TTG_20250305T100029_B04_20m.jp2"
# RED_BAND="../data/T33TTG_20250305T100029_B8A_20m.jp2"
NIR_BAND="../data/T33TTG_20250305T100029_B04_10m.jp2"
RED_BAND="../data/T33TTG_20250305T100029_B08_10m.jp2"
# from S2B_MSIL2A_20250305T100029_N0511_R122_T33TTG_20250305T124852.SAFE

OUTPUT_FILE="../output/gdal_calc.tif"

if command -v gdal_calc &> /dev/null; then
  GDAL_CALC="gdal_calc"
else
  GDAL_CALC="gdal_calc.py"
fi

mkdir -p ../output



# with correction

time $GDAL_CALC \
  --calc="numpy.where(((A-1000)/10000.0+(B-1000)/10000.0)>0, ((A-1000)/10000.0-(B-1000)/10000.0)/((A-1000)/10000.0+(B-1000)/10000.0), -999)" \
  -A $NIR_BAND \
  -B $RED_BAND \
  --outfile=$OUTPUT_FILE \
  --NoDataValue=-999 \
  --type=Float32 \
  --co="COMPRESS=DEFLATE" \
  --co="TILED=YES" \
  --overwrite
