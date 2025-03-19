# GeoSpectraCalc Benchmark Results
- **Date:** Wed Mar 19 10:47:50 CET 2025
- **System:** minto
- **CPU:** Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
- **Cores:** 20 logical, 10 physical
- **Memory:** 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.554s | 301M |
| Rust (whole-image) | 3.107s | 301M |
| Rust (chunked-parallel) | 3.275s | 301M |
| Rust (fixed-point) | 2.577s | 191M |
| Rust (direct-gdal) | 2.579s | N/A |
| Rust (parallel-io) | 2.201s | 191M |
| GRASS GIS | 7.998s | 4.0K |
| Zig (SIMD) | 2.540s | 191M |
