# Performance Benchmarking

## Running the Benchmarks

This repository includes a comprehensive benchmark script that runs all implementations and generates a detailed performance report:

```bash
# Make the script executable
chmod +x run_benchmarks.sh

# Run all benchmarks
./run_benchmarks.sh
```

The script will:
1. Check for required data files
2. Run all implementations (C, Rust variants)
3. Measure execution time and output size
4. Generate a markdown report in the `benchmark_reports` directory

## Benchmark Reports

Reports are saved as markdown files in the `benchmark_reports` directory with the following naming convention:
```
benchmark_YYYY-MM-DD_HOSTNAME.md
```

Each report includes:
- System information (CPU, memory, OS)
- Results sorted from fastest to slowest
- Output file sizes
- Brief descriptions of each implementation

## Sharing Your Benchmark Results

We welcome benchmark results from different hardware configurations. To share your results:

1. Run the benchmark script on your system
2. Submit a pull request that includes your generated report
3. Ensure your report includes complete system information

This helps build a comprehensive understanding of how different implementations perform across various hardware setups.

## Test Data Requirements

The benchmark requires Sentinel-2 band files in the `data` directory:
- `T33TTG_20250305T100029_B08_10m.jp2` (NIR band)
- `T33TTG_20250305T100029_B04_10m.jp2` (RED band)

If you don't have these files, please see the download instructions in the main README.