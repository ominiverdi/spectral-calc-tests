const std = @import("std");
const c = @cImport({
    @cInclude("gdal.h");
    @cInclude("cpl_conv.h");
});

pub fn main() !void {
    c.GDALAllRegister();

    const nir_path = "../data/T33TTG_20250305T100029_B08_10m.jp2";
    const red_path = "../data/T33TTG_20250305T100029_B04_10m.jp2";
    const output_path = "../output/zig_ndvi.tif";

    const nir_ds = c.GDALOpen(nir_path, c.GA_ReadOnly);
    const red_ds = c.GDALOpen(red_path, c.GA_ReadOnly);

    if (nir_ds == null or red_ds == null) {
        std.debug.print("Error: Could not open input datasets\n", .{});
        return error.OpenFailed;
    }
    defer _ = c.GDALClose(nir_ds);
    defer _ = c.GDALClose(red_ds);

    const width = c.GDALGetRasterXSize(nir_ds);
    const height = c.GDALGetRasterYSize(nir_ds);
    const total_pixels = @as(usize, @intCast(width * height));

    var geo_transform: [6]f64 = undefined;
    _ = c.GDALGetGeoTransform(nir_ds, &geo_transform);
    const projection = c.GDALGetProjectionRef(nir_ds);

    const driver = c.GDALGetDriverByName("GTiff");
    
    // Add compression options
    var options = [_][*c]u8{
        @constCast("COMPRESS=DEFLATE"), 
        @constCast("TILED=YES"), 
        @constCast("BIGTIFF=YES"), 
        @constCast("NUM_THREADS=ALL_CPUS"), 
        null
    };

    const out_ds = c.GDALCreate(driver, output_path, width, height, 1, c.GDT_Int16, &options);
    
    if (out_ds == null) {
        std.debug.print("Error: Could not create output dataset\n", .{});
        return error.CreateFailed;
    }
    defer _ = c.GDALClose(out_ds);

    _ = c.GDALSetGeoTransform(out_ds, &geo_transform);
    _ = c.GDALSetProjection(out_ds, projection);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const nir_band = try allocator.alloc(f32, total_pixels);
    defer allocator.free(nir_band);

    const red_band = try allocator.alloc(f32, total_pixels);
    defer allocator.free(red_band);

    const ndvi_band = try allocator.alloc(i16, total_pixels);
    defer allocator.free(ndvi_band);

    const nir_band_result = c.GDALRasterIO(
        c.GDALGetRasterBand(nir_ds, 1), 
        c.GF_Read, 
        0, 0, width, height, 
        nir_band.ptr, width, height, 
        c.GDT_Float32, 0, 0
    );

    const red_band_result = c.GDALRasterIO(
        c.GDALGetRasterBand(red_ds, 1), 
        c.GF_Read, 
        0, 0, width, height, 
        red_band.ptr, width, height, 
        c.GDT_Float32, 0, 0
    );

    if (nir_band_result != 0 or red_band_result != 0) {
        std.debug.print("Error reading raster bands\n", .{});
        return error.ReadFailed;
    }

    const scaling_factor = 10000.0;
    const nodata_value: i16 = -10000; // Represents -1.0 in scaled values

    for (0..total_pixels) |i| {
        const nir = (nir_band[i] - 1000.0) / 10000.0;
        const red = (red_band[i] - 1000.0) / 10000.0;

        const ndvi = if (nir + red > 0) 
            (nir - red) / (nir + red)
        else 
            -1.0;

        // Clamp to prevent overflow
        const clamped_ndvi = @max(@min(ndvi, 0.9999), -0.9999);
        ndvi_band[i] = @as(i16, @intFromFloat(clamped_ndvi * scaling_factor));
    }

    const out_band = c.GDALGetRasterBand(out_ds, 1);
    _ = c.GDALSetRasterNoDataValue(out_band, nodata_value);

    const write_result = c.GDALRasterIO(
        out_band, 
        c.GF_Write, 
        0, 0, width, height, 
        ndvi_band.ptr, width, height, 
        c.GDT_Int16, 0, 0
    );

    if (write_result != 0) {
        std.debug.print("Error writing output raster\n", .{});
        return error.WriteFailed;
    }

    std.debug.print("NDVI calculation complete\n", .{});
}