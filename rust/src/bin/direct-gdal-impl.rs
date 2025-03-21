use gdal::raster::{Buffer, RasterCreationOptions};
use gdal::Dataset;
use gdal::DriverManager;
use gdal::Metadata;
use rayon::prelude::*;
use std::path::Path;
use std::time::Instant;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let start = Instant::now();

    // Path to data
    let granule_path = "../data/";
    let nir_path = format!("{}T33TTG_20250305T100029_B08_10m.jp2", granule_path);
    let red_path = format!("{}T33TTG_20250305T100029_B04_10m.jp2", granule_path);
    let output_path = "../output/rust_fixed_point.tif";

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

    // Define scaling factor and nodata value for Int16
    let scaling_factor = 10000;
    let nodata_value = -10000; // Represents -1.0 in scaled values

    // Create output dataset - now with Int16 instead of Float32
    println!("Creating output dataset...");
    let driver = DriverManager::get_driver_by_name("GTiff")?;

    let creation_options =
        RasterCreationOptions::from_iter(["COMPRESS=DEFLATE", "TILED=YES", "NUM_THREADS=ALL_CPUS"]);
    // Use i16 type instead of f32
    let mut out_ds = driver.create_with_band_type_with_options::<i16, _>(
        output_path,
        width,
        height,
        1,
        &creation_options,
    )?;

    // Copy projection and geotransform
    out_ds.set_projection(&nir_ds.projection())?;
    out_ds.set_geo_transform(&nir_ds.geo_transform()?)?;

    // Set dataset-level metadata FIRST (before getting the band)
    out_ds.set_metadata_item("NDVI_SCALE_FACTOR", "0.0001", "")?;
    out_ds.set_metadata_item("TIFFTAG_GDAL_NODATA", &nodata_value.to_string(), "")?;

    // Now get the band after setting dataset metadata
    let mut out_band = out_ds.rasterband(1)?;

    // Set band-level metadata
    out_band.set_no_data_value(Some(nodata_value as f64))?;
    out_band.set_metadata_item("SCALE", "0.0001", "")?; // 1/scaling_factor
    out_band.set_metadata_item("OFFSET", "0", "")?;
    out_band.set_metadata_item("scale_factor", "0.0001", "")?;
    out_band.set_metadata_item("UNIT_TYPE", "NDVI", "")?;
    out_band.set_description("NDVI")?;

    // Calculate NDVI with fixed-point scaling
    println!("Calculating NDVI...");
    let nir_vec = nir_data.data();
    let red_vec = red_data.data();
    let reflectance_scale = 10000.0f32; // Sentinel-2 scale factor

    // Create result buffer with i16 type
    let mut ndvi_vec = vec![0i16; width as usize * height as usize];

    // Process the entire image in parallel - normalize output to -1 to 1 range
    ndvi_vec.par_iter_mut().enumerate().for_each(|(i, ndvi)| {
        // Apply both scale factor and offset: (DN + offset) / scale_factor
        let nir = (nir_vec[i] - 1000.0) / reflectance_scale;
        let red = (red_vec[i] - 1000.0) / reflectance_scale;

        if nir + red > 0.0 {
            // Calculate NDVI (always between -1 and 1)
            let ndvi_float = (nir - red) / (nir + red);
            // Clamp to [-0.9999, 0.9999] range to avoid int16 overflow
            let clamped_ndvi = ndvi_float.max(-0.9999).min(0.9999);
            // Scale to fixed-point
            *ndvi = (clamped_ndvi * scaling_factor as f32).round() as i16;
        } else {
            *ndvi = nodata_value;
        }
    });

    // Write the entire result at once
    println!("Writing result...");
    let mut band_data = Buffer::new((width as usize, height as usize), ndvi_vec);

    out_band.write((0, 0), (width as usize, height as usize), &mut band_data)?;

    // Add .aux.xml file with display hints
    let aux_file = format!("{}.aux.xml", output_path);
    std::fs::write(
        &aux_file,
        format!(
            r#"<PAMDataset>
  <PAMRasterBand band="1">
    <Description>NDVI</Description>
    <UnitType>NDVI</UnitType>
    <Metadata>
      <MDI key="STATISTICS_MINIMUM">-10000</MDI>
      <MDI key="STATISTICS_MAXIMUM">10000</MDI>
      <MDI key="SCALE">0.0001</MDI>
      <MDI key="OFFSET">0</MDI>
    </Metadata>
    <ColorInterp>Gray</ColorInterp>
  </PAMRasterBand>
</PAMDataset>"#
        ),
    )?;

    out_ds.flush_cache()?;
    println!(
        "NDVI calculation complete in {:.3}s",
        start.elapsed().as_secs_f64()
    );

    Ok(())
}
