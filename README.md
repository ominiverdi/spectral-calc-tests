# GeoSpectraCalc Benchmark

This repository compares different programming implementations for calculating spectral indices from remote sensing data, with a focus on the Normalized Difference Vegetation Index (NDVI).

## Prerequisites

- GDAL with development headers
- C compiler (GCC recommended)
- Rust (latest stable)
- Bash
- GRASS GIS (optional, for comparison)

## Repository Structure

```
spectral-calc-tests/
├── data/                # Test data from Copernicus Sentinel-2
├── output/              # Output directory for results
├── gdal_calc/           # Bash implementation using GDAL utilities
├── c/                   # C implementation using GDAL C API
├── grass/               # GRASS GIS implementation
└── rust/                # Rust implementations
    ├── src/
    │   ├── direct-gdal-impl.rs    # Direct FFI binding to GDAL C API
    │   ├── whole-image-impl.rs    # Process entire image at once using Rust GDAL bindings
    │   └── chunked-parallel-impl.rs  # Process image in chunks with parallel computation
    ├── test-direct.sh
    ├── test-whole-image.sh
    ├── test-chunked-parallel.sh
    └── test-compiler-flags.sh     # Test various compiler optimizations
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

### Gdal_calc Implementation
```bash
cd bash
bash calculate_ndvi.sh
```

### GRASS GIS Implementation
```bash
cd grass
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

# Test compiler flag optimizations
bash test-compiler-flags.sh
```

## Performance Results

Tests performed on an Intel Core i9-10900 CPU @ 2.80GHz (10 cores, 20 threads) with Sentinel-2 images:

### 20m Resolution (5490×5490 pixels)

| Implementation | Runtime (s) | Description |
|----------------|------------|-------------|
| Rust (whole-image) | 0.937 | Loads entire image, processes in parallel, single write |
| Rust (direct-gdal) | 1.161 | Uses direct GDAL C API bindings with chunked processing |
| GRASS GIS | 2.619 | GRASS r.mapcalc with import/export operations |
| C | 2.869 | Direct GDAL C API implementation |
| Rust (chunked-parallel) | 2.865 | Processes image in chunks with parallel computation per chunk |
| Bash (gdal_calc.py) | 4.193 | Uses GDAL command-line utilities |

### 10m Resolution (10980×10980 pixels)

| Implementation | Runtime (s) | Description |
|----------------|------------|-------------|
| Rust (whole-image) | 3.000 | Loads entire image, processes in parallel, single write |
| Rust (direct-gdal) | 3.817 | Uses direct GDAL C API bindings with chunked processing |
| GRASS GIS | 8.036 | GRASS r.mapcalc with import/export operations |
| Rust (chunked-parallel) | 9.940 | Processes image in chunks with parallel computation per chunk |
| C | 10.264 | Direct GDAL C API implementation |
| Bash (gdal_calc.py) | 12.165 | Uses GDAL command-line utilities |

## Compiler Optimization Results

Tests of different Rust compiler flags on the whole-image implementation (10m resolution):

| Optimization | Flags | Runtime (s) |
|--------------|-------|-------------|
| Baseline | `-C target-cpu=native -C opt-level=3` | 3.478 |
| Single codegen unit | `-C target-cpu=native -C opt-level=3 -C codegen-units=1` | 3.674 |
| Panic abort | `-C target-cpu=native -C opt-level=3 -C panic=abort` | 3.732 |
| Maximum (no LTO) | `-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort` | 3.733 |
| Cache-friendly implementation | `-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort` | 3.372 |

Interestingly, the baseline optimization performs better than more aggressive compiler flags, but manual cache-friendly optimizations provide the best performance overall. This suggests that algorithm-level optimizations are more impactful than compiler flags for this workload.

## License

MIT License - See LICENSE file for details.