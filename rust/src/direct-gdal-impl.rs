use std::os::raw::{c_int, c_char, c_double};
use std::ffi::{CString, CStr};
use std::ptr;
use std::time::Instant;
use std::slice;
use rayon::prelude::*;

// FFI bindings to GDAL C API
#[allow(non_camel_case_types)]
type GDALDatasetH = *mut libc::c_void;
#[allow(non_camel_case_types)]
type GDALRasterBandH = *mut libc::c_void;
#[allow(non_camel_case_types)]
type GDALDriverH = *mut libc::c_void;

#[link(name = "gdal")]
extern "C" {
    fn GDALAllRegister();
    fn GDALOpen(pszFilename: *const c_char, eAccess: c_int) -> GDALDatasetH;
    fn GDALClose(hDS: GDALDatasetH);
    fn GDALGetRasterXSize(hDS: GDALDatasetH) -> c_int;
    fn GDALGetRasterYSize(hDS: GDALDatasetH) -> c_int;
    fn GDALGetRasterBand(hDS: GDALDatasetH, nBandId: c_int) -> GDALRasterBandH;
    fn GDALRasterIO(
        hBand: GDALRasterBandH, eRWFlag: c_int, nXOff: c_int, nYOff: c_int,
        nXSize: c_int, nYSize: c_int, pData: *mut libc::c_void,
        nBufXSize: c_int, nBufYSize: c_int, eBufType: c_int,
        nPixelSpace: c_int, nLineSpace: c_int
    ) -> c_int;
    fn GDALGetDriverByName(pszName: *const c_char) -> GDALDriverH;
    fn GDALCreate(
        hDriver: GDALDriverH, pszFilename: *const c_char,
        nXSize: c_int, nYSize: c_int, nBands: c_int,
        eType: c_int, papszOptions: *const *const c_char
    ) -> GDALDatasetH;
    fn GDALSetRasterNoDataValue(hBand: GDALRasterBandH, dfNoData: c_double) -> c_int;
    fn GDALGetProjectionRef(hDS: GDALDatasetH) -> *const c_char;
    fn GDALSetProjection(hDS: GDALDatasetH, pszProjection: *const c_char) -> c_int;
    fn GDALGetGeoTransform(hDS: GDALDatasetH, padfTransform: *mut c_double) -> c_int;
    fn GDALSetGeoTransform(hDS: GDALDatasetH, padfTransform: *const c_double) -> c_int;
}

// GDAL access flags
const GA_ReadOnly: c_int = 0;
const GA_Update: c_int = 1;

// GDAL data types
const GDT_Float32: c_int = 6;

// GDAL RasterIO flags
const GF_Read: c_int = 0;
const GF_Write: c_int = 1;

fn main() {
    let start = Instant::now();
    
    // Path to data
    let granule_path = "../data/";
    // let nir_path = format!("{}T33TTG_20250305T100029_B8A_20m.jp2", granule_path);
    // let red_path = format!("{}T33TTG_20250305T100029_B04_20m.jp2", granule_path);
    let nir_path = format!("{}T33TTG_20250305T100029_B08_10m.jp2", granule_path);
    let red_path = format!("{}T33TTG_20250305T100029_B04_10m.jp2", granule_path);
    let output_path = "../output/rust_direct_gdal.tif";
    
    // Constants
    let scale_factor = 10000.0;
    let nodata_value = -999.0;
    
    // Initialize GDAL
    unsafe {
        GDALAllRegister();
        
        // Open input datasets
        println!("Opening datasets...");
        let nir_c_path = CString::new(nir_path).unwrap();
        let red_c_path = CString::new(red_path).unwrap();
        let nir_ds = GDALOpen(nir_c_path.as_ptr(), GA_ReadOnly);
        let red_ds = GDALOpen(red_c_path.as_ptr(), GA_ReadOnly);
        
        if nir_ds.is_null() || red_ds.is_null() {
            panic!("Failed to open input datasets");
        }
        
        // Get dimensions
        let width = GDALGetRasterXSize(nir_ds);
        let height = GDALGetRasterYSize(nir_ds);
        println!("Image size: {}x{}", width, height);
        
        // Get bands
        let nir_band = GDALGetRasterBand(nir_ds, 1);
        let red_band = GDALGetRasterBand(red_ds, 1);
        
        // Create output dataset
        println!("Creating output dataset...");
        let driver_name = CString::new("GTiff").unwrap();
        let driver = GDALGetDriverByName(driver_name.as_ptr());
        
        if driver.is_null() {
            panic!("Failed to get GTiff driver");
        }
        
        // Create options for GTiff driver
        let option1 = CString::new("COMPRESS=DEFLATE").unwrap();
        let option2 = CString::new("TILED=YES").unwrap();
        let option3 = CString::new("BIGTIFF=YES").unwrap();
        let option4 = CString::new("NUM_THREADS=ALL_CPUS").unwrap();
        let mut options = vec![option1.as_ptr(), option2.as_ptr(), option3.as_ptr(), option4.as_ptr()];
        options.push(ptr::null());
        
        let output_c_path = CString::new(output_path).unwrap();
        let out_ds = GDALCreate(
            driver,
            output_c_path.as_ptr(),
            width,
            height,
            1,
            GDT_Float32,
            options.as_ptr(),
        );
        
        if out_ds.is_null() {
            panic!("Failed to create output dataset");
        }
        
        // Copy projection and geotransform
        let projection = GDALGetProjectionRef(nir_ds);
        if !projection.is_null() {
            GDALSetProjection(out_ds, projection);
        }
        
        let mut transform: [c_double; 6] = [0.0; 6];
        if GDALGetGeoTransform(nir_ds, transform.as_mut_ptr()) == 0 {
            GDALSetGeoTransform(out_ds, transform.as_ptr());
        }
        
        let out_band = GDALGetRasterBand(out_ds, 1);
        GDALSetRasterNoDataValue(out_band, nodata_value);
        
        // Calculate NDVI in chunks for memory efficiency
        println!("Calculating NDVI...");
        
        let num_cpus = std::thread::available_parallelism()
            .map(|n| n.get() as i32)
            .unwrap_or(4);
        
        let chunk_height = 2048; // Use fixed chunk size for better results
        let total_pixels_per_chunk = (width * chunk_height) as usize;

        // Process in chunks
        for y_offset in (0..height).step_by(chunk_height as usize) {
            let actual_height = std::cmp::min(chunk_height, height - y_offset);
            let total_pixels = (width * actual_height) as usize;
            
            // Read NIR band data
            let mut nir_data = vec![0.0f32; total_pixels];
            GDALRasterIO(
                nir_band, GF_Read, 0, y_offset, width, actual_height,
                nir_data.as_mut_ptr() as *mut libc::c_void,
                width, actual_height, GDT_Float32, 0, 0
            );
            
            // Read RED band data
            let mut red_data = vec![0.0f32; total_pixels];
            GDALRasterIO(
                red_band, GF_Read, 0, y_offset, width, actual_height,
                red_data.as_mut_ptr() as *mut libc::c_void,
                width, actual_height, GDT_Float32, 0, 0
            );
            
            // Allocate output array
            let mut ndvi_data = vec![0.0f32; total_pixels];
            
            // Calculate NDVI in parallel
            ndvi_data.par_iter_mut().enumerate().for_each(|(i, ndvi)| {
                let nir = nir_data[i] / scale_factor as f32;
                let red = red_data[i] / scale_factor as f32;
                
                *ndvi = if nir + red > 0.0 {
                    (nir - red) / (nir + red)
                } else {
                    nodata_value as f32
                };
            });
            
            // Write result
            GDALRasterIO(
                out_band, GF_Write, 0, y_offset, width, actual_height,
                ndvi_data.as_mut_ptr() as *mut libc::c_void,
                width, actual_height, GDT_Float32, 0, 0
            );
            
            println!("Processed chunk at y={}, {:.1}% complete",
                     y_offset, (y_offset as f64 + actual_height as f64) / height as f64 * 100.0);
        }
        
        // Clean up
        GDALClose(out_ds);
        GDALClose(nir_ds);
        GDALClose(red_ds);
    }
    
    println!("NDVI calculation complete in {:.3}s", start.elapsed().as_secs_f64());
}