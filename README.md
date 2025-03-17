# spectral-calc-tests Benchmark

This repository compares different programming implementations for calculating spectral indices from remote sensing data, with a focus on the Normalized Difference Vegetation Index (NDVI).

## Prerequisites

- GDAL with development headers
- C compiler (GCC recommended)
- Rust (latest stable)
- Bash

## Repository Structure

```
spectral-calc-tests/
├── data/                # Test data from Copernicus Sentinel-2
├── output/              # Output directory for results
├── bash/                # Bash implementation using GDAL utilities
├── c/                   # C implementation using GDAL C API
└── rust/                # Rust implementations
    ├── src/
    │   ├── direct-gdal-impl.rs    # Direct FFI binding to GDAL C API
    │   ├── whole-image-impl.rs    # Process entire image at once using Rust GDAL bindings
    │   └── chunked-parallel-impl.rs  # Process image in chunks with parallel computation
    ├── test-direct.sh
    ├── test-whole-image.sh
    └── test-chunked-parallel.sh
```

## Data

The repository includes test data from Copernicus Sentinel-2:

### 20m Resolution (included in repo)
- `T33TTG_20250305T100029_B8A_20m.jp2` (NIR band)
- `T33TTG_20250305T100029_B04_20m.jp2` (RED band)

### 10m Resolution (download required)
Download these files for higher resolution tests:
- `T33TTG_20250305T100029_B08_10m.jp2` (NIR band): [Download](https://test.lorenzobecchi.com/T33TTG_20250305T100029_B08_10m.jp2)
- `T33TTG_20250305T100029_B04_10m.jp2` (RED band): [Download](https://test.lorenzobecchi.com/T33TTG_20250305T100029_B04_10m.jp2)

*Note: 10m resolution files are large, around 100MB each*

## Running Tests

### C Implementation
```bash
cd c
bash compile_and_run.sh
```

### Bash Implementation
```bash
cd bash
bash calculate_ndvi.sh
```

### Rust Implementations
```bash
cd rust
# Test direct GDAL FFI implementation
bash test-direct.sh

# Test whole-image implementation
bash test-whole-image.sh

# Test chunked parallel implementation
bash test-chunked-parallel.sh
```

## Performance Results

Tests performed on an Intel Core i9-10900 CPU @ 2.80GHz (10 cores, 20 threads) with Sentinel-2 images:

### 20m Resolution (5490×5490 pixels)

| Implementation | Runtime (s) | Description |
|----------------|------------|-------------|
| C | 0.866 | Direct GDAL C API implementation |
| Rust (whole-image) | 0.937 | Loads entire image, processes in parallel, single write |
| Rust (direct-gdal) | 1.161 | Uses direct GDAL C API bindings with chunked processing |
| Rust (chunked-parallel) | 2.865 | Processes image in chunks with parallel computation per chunk |
| Bash (gdal_calc.py) | 4.193 | Uses GDAL command-line utilities |

### 10m Resolution (10980×10980 pixels)

| Implementation | Runtime (s) | Description |
|----------------|------------|-------------|
| C | 2.762 | Direct GDAL C API implementation |
| Rust (whole-image) | 3.000 | Loads entire image, processes in parallel, single write |
| Rust (direct-gdal) | 3.817 | Uses direct GDAL C API bindings with chunked processing |
| Rust (chunked-parallel) | 9.940 | Processes image in chunks with parallel computation per chunk |
| Bash (gdal_calc.py) | 12.165 | Uses GDAL command-line utilities |

## License

MIT License - See LICENSE file for details.