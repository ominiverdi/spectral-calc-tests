use gdal::raster::{Buffer, RasterCreationOptions};
use gdal::Dataset;
use gdal::DriverManager;
use rayon::prelude::*;
use std::path::Path;
use std::time::Instant;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let start = Instant::now();

    // Path to data
    let granule_path = "../data/";
    let nir_path = format!("{}T33TTG_20250305T100029_B08_10m.jp2", granule_path);
    let red_path = format!("{}T33TTG_20250305T100029_B04_10m.jp2", granule_path);
    let output_path = "../output/rust_optimized.tif";

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

    let creation_options =
        RasterCreationOptions::from_iter(["COMPRESS=DEFLATE", "TILED=YES", "NUM_THREADS=ALL_CPUS"]);
    let mut out_ds = driver.create_with_band_type_with_options::<f32, _>(
        output_path,
        width,
        height,
        1,
        &creation_options,
    )?;

    // Copy projection and geotransform
    out_ds.set_projection(&nir_ds.projection())?;
    out_ds.set_geo_transform(&nir_ds.geo_transform()?)?;

    let mut out_band = out_ds.rasterband(1)?;
    let nodata_value = -999.0;
    out_band.set_no_data_value(Some(nodata_value))?;

    // Calculate NDVI using optimized approach
    println!("Calculating NDVI...");
    let nir_vec = nir_data.data();
    let red_vec = red_data.data();
    let scale_factor = 10000.0f32;

    // Create result buffer
    let mut ndvi_vec = vec![0.0f32; width as usize * height as usize];

    // Process in larger chunks (cache-friendly)
    const CHUNK_SIZE: usize = 4096;

    // Configure workload with better distribution
    let num_threads = rayon::current_num_threads();
    let total_pixels = nir_vec.len();
    let pixels_per_thread = (total_pixels + num_threads - 1) / num_threads;

    // Process in parallel with optimal chunk sizes
    ndvi_vec
        .par_chunks_mut(pixels_per_thread)
        .enumerate()
        .for_each(|(chunk_id, ndvi_chunk)| {
            let start = chunk_id * pixels_per_thread;
            let end = std::cmp::min(start + pixels_per_thread, total_pixels);

            // Process each block in this chunk
            for block_start in (start..end).step_by(CHUNK_SIZE) {
                let block_end = std::cmp::min(block_start + CHUNK_SIZE, end);
                let block_size = block_end - block_start;

                // Process this block
                for i in 0..block_size {
                    let global_idx = block_start + i;
                    let local_idx = i;

                    // Compute NDVI
                    let nir = (nir_vec[global_idx] - 1000.0) / scale_factor;
                    let red = (red_vec[global_idx] - 1000.0) / scale_factor;

                    ndvi_chunk[local_idx] = if nir + red > 0.0 {
                        (nir - red) / (nir + red)
                    } else {
                        nodata_value as f32
                    };
                }
            }
        });

    // Write the entire result at once
    println!("Writing result...");
    let mut band_data = Buffer::new((width as usize, height as usize), ndvi_vec);

    out_band.write((0, 0), (width as usize, height as usize), &mut band_data)?;

    out_ds.flush_cache()?;
    println!(
        "NDVI calculation complete in {:.3}s",
        start.elapsed().as_secs_f64()
    );

    Ok(())
}
