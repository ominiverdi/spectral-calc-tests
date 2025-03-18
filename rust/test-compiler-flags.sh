#!/bin/bash
set -e

# Create results directory
mkdir -p ../benchmark_results

# Path to save benchmark results
RESULTS_FILE="../benchmark_results/compiler_flags_benchmark.txt"
echo "# RUST COMPILER FLAGS BENCHMARK" > $RESULTS_FILE
echo "Testing different compiler optimization flags on $(date)" >> $RESULTS_FILE
echo "System: $(uname -a)" >> $RESULTS_FILE
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^ *//')" >> $RESULTS_FILE
echo "Number of cores: $(nproc)" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Set common environment variables
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES



# Define the flags combinations to test
declare -a RUST_FLAGS_VARIANTS=(
    "-C target-cpu=native -C opt-level=3"
    "-C target-cpu=native -C opt-level=3 -C codegen-units=1"
    "-C target-cpu=native -C opt-level=3 -C panic=abort"
    "-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort"
)

declare -a VARIANT_NAMES=(
    "Baseline (opt-level=3)"
    "Single codegen unit"
    "With panic=abort"
    "Maximum optimization (no LTO)"
)

# Function to run the benchmark with specific flags
run_benchmark() {
    local flags="$1"
    local name="$2"

    echo "----------------------------------------------"
    echo "Testing: $name"
    echo "Flags: $flags"

    echo "Building with flags..."
    RUSTFLAGS="$flags" cargo build --release  --quiet

    echo "Running benchmark..."
    # Run 3 times and take the average
    local total_time=0
    local runs=3

    for i in $(seq 1 $runs); do
        echo "Run $i/$runs"
        start_time=$(date +%s.%N)
        ./target/release/geo-spectra-calc
        end_time=$(date +%s.%N)
        runtime=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $runtime" | bc)
        echo "Time: $runtime seconds"
    done

    avg_time=$(echo "scale=3; $total_time / $runs" | bc)
    echo "Average runtime: $avg_time seconds"

    # Record results
    echo "## $name" >> $RESULTS_FILE
    echo "Flags: \`$flags\`" >> $RESULTS_FILE
    echo "Average runtime: $avg_time seconds" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE

    return 0
}

# Run each variant
for i in "${!RUST_FLAGS_VARIANTS[@]}"; do
    run_benchmark "${RUST_FLAGS_VARIANTS[$i]}" "${VARIANT_NAMES[$i]}"
done

# Test manual cache-friendly implementation
echo "----------------------------------------------"
echo "Testing: Manual optimization approach"

# Create a manual optimization version
cat > src/manual_optimized.rs << 'EOF'
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
    let nodata_value = -999.0;
    out_band.set_no_data_value(Some(nodata_value))?;

    // Calculate NDVI using optimized approach
    println!("Calculating NDVI...");
    let nir_vec = nir_data.data;
    let red_vec = red_data.data;
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
    ndvi_vec.par_chunks_mut(pixels_per_thread)
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
    let band_data = Buffer::new(
        (width as usize, height as usize),
        ndvi_vec
    );

    out_band.write((0, 0), (width as usize, height as usize), &band_data)?;

    out_ds.flush_cache()?;
    println!("NDVI calculation complete in {:.3}s", start.elapsed().as_secs_f64());

    Ok(())
}
EOF

# Use the optimized implementation
cp src/manual_optimized.rs src/main.rs

# Build with maximum optimization
cargo clean > /dev/null
echo "Building with optimized implementation..."
RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort" cargo build --release  --quiet

echo "Running manually optimized benchmark..."
# Run 3 times and take the average
total_time=0
runs=3

for i in $(seq 1 $runs); do
    echo "Run $i/$runs"
    start_time=$(date +%s.%N)
    ./target/release/geo-spectra-calc
    end_time=$(date +%s.%N)
    runtime=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $runtime" | bc)
    echo "Time: $runtime seconds"
done

avg_time=$(echo "scale=3; $total_time / $runs" | bc)
echo "Average runtime: $avg_time seconds"

# Record results
echo "## Cache-friendly manual optimization" >> $RESULTS_FILE
echo "Flags: \`-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort\`" >> $RESULTS_FILE
echo "Average runtime: $avg_time seconds" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Clean up
rm src/manual_optimized.rs
rm src/main.rs
touch src/main.rs

echo "----------------------------------------------"
echo "Benchmark complete. Results saved to $RESULTS_FILE"
cat $RESULTS_FILE
