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

# Save the current implementation for restoring later
cp src/main.rs src/main.rs.orig
cp src/whole-image-impl.rs src/main.rs

# Define the flags combinations to test
declare -a RUST_FLAGS_VARIANTS=(
    "-C target-cpu=native -C opt-level=3"
    "-C target-cpu=native -C opt-level=3 -C lto=thin"
    "-C target-cpu=native -C opt-level=3 -C lto=fat"
    "-C target-cpu=native -C opt-level=3 -C lto=fat -C codegen-units=1"
    "-C target-cpu=native -C opt-level=3 -C lto=fat -C codegen-units=1 -C panic=abort"
)

declare -a VARIANT_NAMES=(
    "Baseline (opt-level=3)"
    "With thin LTO"
    "With fat LTO"
    "With fat LTO + single codegen unit"
    "Maximum optimization"
)

# Function to run the benchmark with specific flags
run_benchmark() {
    local flags="$1"
    local name="$2"
    
    echo "----------------------------------------------"
    echo "Testing: $name"
    echo "Flags: $flags"
    
    # Clean and rebuild with the specified flags
    cargo clean
    RUSTFLAGS="$flags" cargo build --release
    
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

# Test SIMD-optimized version if x86_64 architecture
if [ "$(uname -m)" == "x86_64" ]; then
    echo "----------------------------------------------"
    echo "Testing: SIMD-optimized implementation"
    
    # Backup current implementation
    cp src/main.rs src/main.rs.bak
    
    # Apply SIMD optimizations
    cat src/whole-image-impl.rs > src/main.rs.simd
    # Add SIMD implementation
    echo '
// Add SIMD optimization for NDVI calculation
#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

#[cfg(target_arch = "x86_64")]
fn calculate_ndvi_simd(nir: &[f32], red: &[f32], output: &mut [f32], scale_factor: f32, nodata: f32) {
    let len = nir.len();
    let chunks = len / 8;
    
    // Process 8 elements at a time using AVX
    unsafe {
        let scale_factor_vec = _mm256_set1_ps(scale_factor);
        let offset_vec = _mm256_set1_ps(1000.0);
        let zero_vec = _mm256_setzero_ps();
        let nodata_vec = _mm256_set1_ps(nodata);
        
        for i in 0..chunks {
            let idx = i * 8;
            
            // Load NIR and RED data
            let nir_vec = _mm256_loadu_ps(nir.as_ptr().add(idx));
            let red_vec = _mm256_loadu_ps(red.as_ptr().add(idx));
            
            // Apply offset and scale: (val - 1000.0) / scale_factor
            let nir_scaled = _mm256_div_ps(_mm256_sub_ps(nir_vec, offset_vec), scale_factor_vec);
            let red_scaled = _mm256_div_ps(_mm256_sub_ps(red_vec, offset_vec), scale_factor_vec);
            
            // Calculate sum and diff
            let sum = _mm256_add_ps(nir_scaled, red_scaled);
            let diff = _mm256_sub_ps(nir_scaled, red_scaled);
            
            // Check if sum > 0
            let mask = _mm256_cmp_ps(sum, zero_vec, _CMP_GT_OQ);
            
            // Calculate NDVI where sum > 0
            let ndvi = _mm256_div_ps(diff, sum);
            
            // Select NDVI or nodata based on mask
            let result = _mm256_blendv_ps(nodata_vec, ndvi, mask);
            
            // Store the result
            _mm256_storeu_ps(output.as_mut_ptr().add(idx), result);
        }
    }
    
    // Handle remaining elements
    let remainder_start = chunks * 8;
    for i in remainder_start..len {
        let nir_val = (nir[i] - 1000.0) / scale_factor;
        let red_val = (red[i] - 1000.0) / scale_factor;
        
        output[i] = if nir_val + red_val > 0.0 {
            (nir_val - red_val) / (nir_val + red_val)
        } else {
            nodata
        };
    }
}' >> src/main.rs.simd
    
    # Update the main calculation part to use SIMD
    sed -i 's/ndvi_vec.par_iter_mut().enumerate().for_each(|(i, ndvi)| {/\
    if cfg!(target_arch = "x86_64") {\
        if is_x86_feature_detected!("avx2") {\
            calculate_ndvi_simd(\&nir_vec, \&red_vec, \&mut ndvi_vec, scale_factor, nodata_value as f32);\
        } else {\
            ndvi_vec.par_iter_mut().enumerate().for_each(|(i, ndvi)| {/g' src/main.rs.simd
    
    # Close the conditional
    sed -i 's/});/});\
        }\
    } else {\
        ndvi_vec.par_iter_mut().enumerate().for_each(|(i, ndvi)| {\
            let nir = (nir_vec[i] - 1000.0) \/ scale_factor;\
            let red = (red_vec[i] - 1000.0) \/ scale_factor;\
            \
            *ndvi = if nir + red > 0.0 {\
                (nir - red) \/ (nir + red)\
            } else {\
                nodata_value as f32\
            };\
        });\
    }/g' src/main.rs.simd
    
    # Add is_x86_feature_detected macro
    sed -i '1s/^/#![feature(is_x86_feature_detected)]\n/' src/main.rs.simd
    
    # Use the SIMD implementation
    cp src/main.rs.simd src/main.rs
    
    # Build with maximum optimization
    cargo clean
    RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=fat -C codegen-units=1 -C panic=abort" cargo build --release
    
    echo "Running SIMD-optimized benchmark..."
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
    echo "## SIMD-optimized (AVX2) implementation" >> $RESULTS_FILE
    echo "Flags: \`-C target-cpu=native -C opt-level=3 -C lto=fat -C codegen-units=1 -C panic=abort\`" >> $RESULTS_FILE
    echo "Average runtime: $avg_time seconds" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    
    # Clean up
    rm src/main.rs.simd
fi

# Restore the original implementation
cp src/main.rs.orig src/main.rs
rm src/main.rs.orig

echo "----------------------------------------------"
echo "Benchmark complete. Results saved to $RESULTS_FILE"
cat $RESULTS_FILE