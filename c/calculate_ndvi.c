#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gdal.h>
#include <cpl_conv.h>
#include <math.h>

int main(int argc, char *argv[]) {
    GDALAllRegister();
    
    // Paths to your data
    const char *nirPath = "../data/T33TTG_20250305T100029_B8A_20m.jp2";
    const char *redPath = "../data/T33TTG_20250305T100029_B04_20m.jp2";
    const char *outputPath = "../output/c.tif";
    
    // Open datasets
    GDALDatasetH nirDS = GDALOpen(nirPath, GA_ReadOnly);
    GDALDatasetH redDS = GDALOpen(redPath, GA_ReadOnly);
    
    if (nirDS == NULL || redDS == NULL) {
        fprintf(stderr, "Error: Could not open input datasets\n");
        return 1;
    }
    
    // Get dataset dimensions
    int width = GDALGetRasterXSize(nirDS);
    int height = GDALGetRasterYSize(nirDS);
    
    // Create output dataset
    GDALDriverH driver = GDALGetDriverByName("GTiff");
    GDALDatasetH outDS = GDALCreate(driver, outputPath, width, height, 1, GDT_Float32, NULL);
    
    if (outDS == NULL) {
        fprintf(stderr, "Error: Could not create output dataset\n");
        return 1;
    }
    
    // Copy projection and geotransform from input
    GDALSetProjection(outDS, GDALGetProjectionRef(nirDS));
    double geoTransform[6];
    GDALGetGeoTransform(nirDS, geoTransform);
    GDALSetGeoTransform(outDS, geoTransform);
    
    // Allocate memory for raster data
    float *nirBand = (float *)malloc(sizeof(float) * width * height);
    float *redBand = (float *)malloc(sizeof(float) * width * height);
    float *ndviBand = (float *)malloc(sizeof(float) * width * height);
    
    // Read raster data
    GDALRasterBandH nirRasterBand = GDALGetRasterBand(nirDS, 1);
    GDALRasterBandH redRasterBand = GDALGetRasterBand(redDS, 1);
    
    GDALRasterIO(nirRasterBand, GF_Read, 0, 0, width, height, nirBand, width, height, GDT_Float32, 0, 0);
    GDALRasterIO(redRasterBand, GF_Read, 0, 0, width, height, redBand, width, height, GDT_Float32, 0, 0);
    
    // Sentinel-2 data needs to be scaled by 10000 to get reflectance values between 0 and 1
    const float scale = 10000.0;
    
    // Calculate NDVI
    for (int i = 0; i < width * height; i++) {
        float nir = nirBand[i] / scale;
        float red = redBand[i] / scale;
        
        if (nir + red > 0) {
            ndviBand[i] = (nir - red) / (nir + red);
        } else {
            ndviBand[i] = -999.0; // NoData value
        }
    }
    
    // Write NDVI to output
    GDALRasterBandH outRasterBand = GDALGetRasterBand(outDS, 1);
    GDALRasterIO(outRasterBand, GF_Write, 0, 0, width, height, ndviBand, width, height, GDT_Float32, 0, 0);
    
    // Set NoData value
    GDALSetRasterNoDataValue(outRasterBand, -999.0);
    
    // Clean up
    free(nirBand);
    free(redBand);
    free(ndviBand);
    GDALClose(nirDS);
    GDALClose(redDS);
    GDALClose(outDS);
    
    printf("NDVI calculation complete. Output saved to %s\n", outputPath);
    
    return 0;
}
