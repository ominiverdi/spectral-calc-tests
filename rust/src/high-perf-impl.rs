use gdal::Dataset;
use gdal::DriverManager;
use gdal::raster::{RasterCreationOption, Buffer};
use std::path::Path;
use std::time::Instant;
use std::sync::Arc;
use rayon::prelude::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let start = Instant::now();
    
    // Path to data
    let granule_path = "../../data/";
    let nir_path = format!("{}T33TTG_20250305T100029_B8A_20m.jp2", granule_path);
    let red_path = format!("{}/T33TTG_20250305T100029_B04_20m.jp2", granule_path);
    let output_path = "../../output/rust_high_perf.tif";

    // Constants
    let scale_factor = 10000.0;
    let nodata_value = -999.0;
    
    // Open datasets and preload all data at once
    println!("Opening and loading datasets...");
    let nir_ds = Dataset::open(Path::new(&nir_path))?;
    let red_ds = Dataset::open(Path::new(&red_path))?;
    
    // Get dimensions
    let (width, height) = nir_ds.raster_size();
    println!("Image size: {}x{}", width, height);
    
    // Get bands
    let nir_band = nir_ds.rasterband(1)?;
    let red_band = red_ds.rasterband(1)?;
    
    // Read all data at once
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
    
    // Convert to Arc for efficient sharing
    let nir_vec = Arc::new(nir_data.data);
    let red_vec = Arc::new(red_data.data);
    
    // Create output dataset first
    println!("Creating output dataset...");
    let driver = DriverManager::get_driver_by_name("GTiff")?;
    let options = vec![
        RasterCreationOption { key: "COMPRESS", value: "DEFLATE" },
        RasterCreationOption { key: "TILED", value: "YES" },
        RasterCreationOption { key: "BIGTIFF", value: "YES" },
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
    out_band.set_no_data_value(Some(nodata_value))?;
    
    // Calculate NDVI using all CPU cores
    println!("Calculating NDVI...");
    
    // Determine optimal chunk size based on CPU count
    let num_cpus = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
    let chunk_height = (height as usize + num_cpus - 1) / num_cpus;
    
    // Calculate NDVI
    (0..height as usize).step_by(chunk_height)
        .collect::<Vec<_>>()
        .par_iter()
        .for_each(|&chunk_start| {
            let actual_chunk_height = std::cmp::min(chunk_height, height as usize - chunk_start);
            let start_idx = chunk_start * width as usize;
            let end_idx = start_idx + actual_chunk_height * width as usize;
            
            let nir_vec = Arc::clone(&nir_vec);
            let red_vec = Arc::clone(&red_vec);
            
            // Create result buffer for this chunk
            let mut ndvi_chunk = Vec::with_capacity(actual_chunk_height * width as usize);
            
            // Calculate NDVI for each pixel in the chunk
            for i in start_idx..end_idx {
                let nir = nir_vec[i] / scale_factor as f32;
                let red = red_vec[i] / scale_factor as f32;
                
                let ndvi = if nir + red > 0.0 {
                    (nir - red) / (nir + red)
                } else {
                    nodata_value as f32
                };
                
                ndvi_chunk.push(ndvi);
            }
            
            // Write this chunk
            let band_data = Buffer::new(
                (width as usize, actual_chunk_height),
                ndvi_chunk
            );
            
            // Use a mutex to protect writing
            {
                out_band.write(
                    (0, chunk_start as isize), 
                    (width as usize, actual_chunk_height),
                    &band_data
                ).expect("Failed to write chunk");
            }
            
            println!("Processed chunk at y={}, {:.1}% complete", 
                     chunk_start, (chunk_start as f64 + actual_chunk_height as f64) / height as f64 * 100.0);
        });
    
    // Flush and close
    out_ds.flush_cache()?;
    
    println!("NDVI calculation complete in {:.3}s", start.elapsed().as_secs_f64());
    
    Ok(())
}