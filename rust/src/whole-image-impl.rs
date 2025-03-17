use gdal::Dataset;
use gdal::DriverManager;
use gdal::raster::{RasterCreationOption, Buffer};
use std::path::Path;
use std::time::Instant;
use rayon::prelude::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let start = Instant::now();
    
    // Path to data
    let granule_path = "../data/";
    let nir_path = format!("{}T33TTG_20250305T100029_B8A_20m.jp2", granule_path);
    let red_path = format!("{}T33TTG_20250305T100029_B04_20m.jp2", granule_path);
    let output_path = "../output/rust_whole_image.tif";
    
    // Open datasets
    println!("Opening datasets...");
    let nir_ds = Dataset::open(Path::new(&nir_path))?;
    let red_ds = Dataset::open(Path::new(&red_path))?;
    
    // Get dimensions
    let (width, height) = nir_ds.raster_size();
    println!("Image size: {}x{}", width, height);
    
    // Get bands
    let nir_band = nir_ds.rasterband(1)?;
    let red_band = red_ds.rasterband(1)?;
    
    // Read the entire image at once
    println!("Reading entire image...");
    let nir_data = nir_band.read_as::<f32>(
        (0, 0), 
        (width as usize, height as usize),
        (width as usize, height as usize),
        None,
    )?;
    
    let red_data = red_band.read_as::<f32>(
        (0, 0), 
        (width as usize, height as usize),
        (width as usize, height as usize),
        None,
    )?;
    
    // Create output dataset
    println!("Creating output dataset...");
    let driver = DriverManager::get_driver_by_name("GTiff")?;
    let options = vec![
        RasterCreationOption { key: "COMPRESS", value: "DEFLATE" },
        RasterCreationOption { key: "TILED", value: "YES" },
        RasterCreationOption { key: "BIGTIFF", value: "YES" },
        RasterCreationOption { key: "NUM_THREADS", value: "ALL_CPUS" },
    ];
    
    let mut out_ds = driver.create_with_band_type_with_options::<f32, _>(
        output_path,
        width as isize,
        height as isize,
        1,
        &options,
    )?;
    
    // Copy projection and geotransform
    out_ds.set_projection(&nir_ds.projection())?;
    out_ds.set_geo_transform(&nir_ds.geo_transform()?)?;
    
    let mut out_band = out_ds.rasterband(1)?;
    let nodata_value = -999.0;
    out_band.set_no_data_value(Some(nodata_value))?;
    
    // Calculate NDVI
    println!("Calculating NDVI...");
    let nir_vec = nir_data.data;
    let red_vec = red_data.data;
    let scale_factor = 10000.0f32;
    
    // Create result buffer
    let mut ndvi_vec = vec![0.0f32; width as usize * height as usize];
    
    // Process the entire image in parallel
    ndvi_vec.par_iter_mut().enumerate().for_each(|(i, ndvi)| {
        let nir = nir_vec[i] / scale_factor;
        let red = red_vec[i] / scale_factor;
        
        *ndvi = if nir + red > 0.0 {
            (nir - red) / (nir + red)
        } else {
            nodata_value as f32
        };
    });
    
    // Write the entire result at once
    println!("Writing result...");
    let band_data = Buffer::new(
        (width as usize, height as usize),
        ndvi_vec
    );
    
    out_band.write((0, 0), (width as usize, height as usize), &band_data)?;
    
    out_ds.flush_cache()?;
    println!("NDVI calculation complete in {:.3}s", start.elapsed().as_secs_f64());
    
    Ok(())
}