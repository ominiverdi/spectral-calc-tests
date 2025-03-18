const std = @import("std");
const c = @cImport({
    @cInclude("gdal.h");
    @cInclude("cpl_conv.h");
});

// Smaller SIMD vector length
const vector_len = 8;

pub fn main() !void {
    const start_time = std.time.nanoTimestamp();
    
    std.debug.print("Initializing GDAL...\n", .{});
    c.GDALAllRegister();

    const nir_path = "../data/T33TTG_20250305T100029_B08_10m.jp2";
    const red_path = "../data/T33TTG_20250305T100029_B04_10m.jp2";
    const output_path = "../output/zig_simd.tif";

    std.debug.print("Opening input datasets...\n", .{});
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
    std.debug.print("Image size: {d}x{d} ({d} pixels)\n", .{width, height, total_pixels});

    var options = [_][*c]u8{
        @constCast("COMPRESS=DEFLATE"), 
        @constCast("TILED=YES"), 
        @constCast("NUM_THREADS=ALL_CPUS"), 
        null
    };

    std.debug.print("Creating output dataset...\n", .{});
    const driver = c.GDALGetDriverByName("GTiff");
    const out_ds = c.GDALCreate(driver, output_path, width, height, 1, c.GDT_Int16, &options);
    
    if (out_ds == null) {
        std.debug.print("Error: Could not create output dataset\n", .{});
        return error.CreateFailed;
    }
    defer _ = c.GDALClose(out_ds);

    std.debug.print("Setting geospatial info...\n", .{});
    var gt: [6]f64 = undefined;
    _ = c.GDALGetGeoTransform(nir_ds, &gt);
    _ = c.GDALSetGeoTransform(out_ds, &gt);
    _ = c.GDALSetProjection(out_ds, c.GDALGetProjectionRef(nir_ds));

    std.debug.print("Allocating memory...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const nir_band = try allocator.alloc(f32, total_pixels);
    defer allocator.free(nir_band);
    const red_band = try allocator.alloc(f32, total_pixels);
    defer allocator.free(red_band);
    const ndvi_band = try allocator.alloc(i16, total_pixels);
    defer allocator.free(ndvi_band);

    std.debug.print("Reading raster data...\n", .{});
    const nir_raster_band = c.GDALGetRasterBand(nir_ds, 1);
    const red_raster_band = c.GDALGetRasterBand(red_ds, 1);

    if (c.GDALRasterIO(
        nir_raster_band, c.GF_Read, 0, 0, width, height,
        nir_band.ptr, width, height, c.GDT_Float32, 0, 0
    ) != 0) {
        std.debug.print("Error reading NIR band\n", .{});
        return error.ReadFailed;
    }

    if (c.GDALRasterIO(
        red_raster_band, c.GF_Read, 0, 0, width, height,
        red_band.ptr, width, height, c.GDT_Float32, 0, 0
    ) != 0) {
        std.debug.print("Error reading RED band\n", .{});
        return error.ReadFailed;
    }

    std.debug.print("Calculating NDVI with SIMD...\n", .{});
    
    // Constants
    const offset: f32 = 1000.0;
    const scale_factor: f32 = 10000.0;
    const nodata_value: i16 = -10000;
    
    // Create SIMD vectors
    const offset_vec: @Vector(vector_len, f32) = @splat(offset);
    const scale_vec: @Vector(vector_len, f32) = @splat(scale_factor);

    // Sequential SIMD processing - no threading for now
    var i: usize = 0;
    while (i + vector_len <= total_pixels) {
        // Load data into vectors
        var nir_vec: @Vector(vector_len, f32) = undefined;
        var red_vec: @Vector(vector_len, f32) = undefined;
        
        for (0..vector_len) |j| {
            nir_vec[j] = nir_band[i + j];
            red_vec[j] = red_band[i + j];
        }
        
        // Apply scale and offset
        const nir_norm = (nir_vec - offset_vec) / scale_vec;
        const red_norm = (red_vec - offset_vec) / scale_vec;
        
        // Calculate sum
        const sum = nir_norm + red_norm;
        
        // Calculate NDVI
        const numerator = nir_norm - red_norm;
        
        // Process each value based on sum > 0
        for (0..vector_len) |j| {
            if (sum[j] > 0.0) {
                var ndvi = numerator[j] / sum[j];
                // Clamp
                ndvi = @max(@min(ndvi, 0.9999), -0.9999);
                ndvi_band[i + j] = @intFromFloat(ndvi * scale_factor);
            } else {
                ndvi_band[i + j] = nodata_value;
            }
        }
        
        i += vector_len;
    }
    
    // Handle remaining pixels
    while (i < total_pixels) {
        const nir = (nir_band[i] - offset) / scale_factor;
        const red = (red_band[i] - offset) / scale_factor;
        const sum = nir + red;
        
        ndvi_band[i] = if (sum > 0.0) 
            blk: {
                const ndvi = (nir - red) / sum;
                const clamped = @max(@min(ndvi, 0.9999), -0.9999);
                break :blk @intFromFloat(clamped * scale_factor);
            } 
        else 
            nodata_value;
        
        i += 1;
    }

    std.debug.print("Writing output...\n", .{});
    const out_band = c.GDALGetRasterBand(out_ds, 1);
    _ = c.GDALSetRasterNoDataValue(out_band, @floatFromInt(nodata_value));
    _ = c.GDALSetMetadataItem(out_band, "SCALE", "0.0001", "");
    _ = c.GDALSetMetadataItem(out_band, "OFFSET", "0", "");
    _ = c.GDALSetDescription(out_band, "NDVI");

    if (c.GDALRasterIO(
        out_band, c.GF_Write, 0, 0, width, height,
        ndvi_band.ptr, width, height, c.GDT_Int16, 0, 0
    ) != 0) {
        std.debug.print("Error writing output raster\n", .{});
        return error.WriteFailed;
    }
    
    std.debug.print("Flushing output...\n", .{});
    _ = c.GDALFlushCache(out_ds);

    const elapsed_ns = std.time.nanoTimestamp() - start_time;
    std.debug.print("NDVI calculation complete in {d:.3}s\n", .{@as(f64, @floatFromInt(elapsed_ns)) / 1e9});
}