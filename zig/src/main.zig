const std = @import("std");
const c = @cImport({
    @cInclude("gdal.h");
    @cInclude("cpl_conv.h");
});

// SIMD vector length - should be a power of 2
const vector_len = 8;

pub fn main() !void {
    const start_time = std.time.nanoTimestamp();
    
    std.debug.print("Initializing GDAL...\n", .{});
    c.GDALAllRegister();

    const nir_path = "../data/T33TTG_20250305T100029_B08_10m.jp2";
    const red_path = "../data/T33TTG_20250305T100029_B04_10m.jp2";
    const output_path = "../output/zig_parallel_simd.tif";

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

    std.debug.print("Calculating NDVI with parallel SIMD...\n", .{});
    
    // Constants
    const offset: f32 = 1000.0;
    const scale_factor: f32 = 10000.0;
    const nodata_value: i16 = -10000;
    
    // Setup multi-threading - determine optimal number of threads
    const cpu_count = try std.Thread.getCpuCount();
    const thread_count = @min(cpu_count, 16); // Cap at 16 threads
    std.debug.print("Using {d} threads\n", .{thread_count});
    
    // Allocate thread handles
    var threads = try allocator.alloc(std.Thread, thread_count);
    defer allocator.free(threads);
    
    // Calculate pixels per thread - use large chunks for better cache locality
    const pixels_per_thread = (total_pixels + thread_count - 1) / thread_count;
    
    // Launch threads
    for (0..thread_count) |thread_idx| {
        const start_idx = thread_idx * pixels_per_thread;
        const end_idx = @min(start_idx + pixels_per_thread, total_pixels);
        
        // Skip if this thread has no work
        if (start_idx >= end_idx) continue;
        
        threads[thread_idx] = try std.Thread.spawn(.{}, struct {
            fn processChunk(
                nir_data: []const f32, 
                red_data: []const f32, 
                ndvi_data: []i16,
                start: usize, 
                end: usize, 
                vec_len: usize,
                offset_val: f32,
                scale_val: f32,
                nodata_val: i16
            ) void {
                // Create SIMD vectors for this thread
                const offset_vec: @Vector(vector_len, f32) = @splat(offset_val);
                const scale_vec: @Vector(vector_len, f32) = @splat(scale_val);
                
                var pos: usize = start;  // Changed from 'i' to 'pos' to avoid shadowing
                
                // Process in SIMD chunks
                while (pos + vec_len <= end) {
                    // Load data into vectors
                    var nir_vec: @Vector(vector_len, f32) = undefined;
                    var red_vec: @Vector(vector_len, f32) = undefined;
                    
                    for (0..vec_len) |j| {
                        nir_vec[j] = nir_data[pos + j];
                        red_vec[j] = red_data[pos + j];
                    }
                    
                    // Apply scale and offset
                    const nir_norm = (nir_vec - offset_vec) / scale_vec;
                    const red_norm = (red_vec - offset_vec) / scale_vec;
                    
                    // Calculate sum and difference
                    const sum = nir_norm + red_norm;
                    const diff = nir_norm - red_norm;
                    
                    // Process each value 
                    for (0..vec_len) |j| {
                        if (sum[j] > 0.0) {
                            var ndvi = diff[j] / sum[j];
                            // Clamp
                            ndvi = @max(@min(ndvi, 0.9999), -0.9999);
                            ndvi_data[pos + j] = @intFromFloat(ndvi * scale_val);
                        } else {
                            ndvi_data[pos + j] = nodata_val;
                        }
                    }
                    
                    pos += vec_len;
                }
                
                // Handle remaining pixels (fewer than vector_len)
                while (pos < end) {
                    const nir = (nir_data[pos] - offset_val) / scale_val;
                    const red = (red_data[pos] - offset_val) / scale_val;
                    const sum = nir + red;
                    
                    ndvi_data[pos] = if (sum > 0.0) 
                        blk: {
                            const ndvi = (nir - red) / sum;
                            const clamped = @max(@min(ndvi, 0.9999), -0.9999);
                            break :blk @intFromFloat(clamped * scale_val);
                        } 
                    else 
                        nodata_val;
                    
                    pos += 1;
                }
            }
        }.processChunk, .{
            nir_band, red_band, ndvi_band, 
            start_idx, end_idx, vector_len,
            offset, scale_factor, nodata_value
        });
    }
    
    // Wait for all threads to complete
    std.debug.print("Waiting for threads to complete...\n", .{});
    for (threads) |thread| {
        thread.join();
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