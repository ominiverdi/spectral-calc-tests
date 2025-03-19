# GeoSpectraCalc Benchmark Results
- **Date:** Wed Mar 19 11:30:55 CET 2025
- **System:** minto
- **CPU:** Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
- **Cores:** 20 logical, 10 physical
- **Memory:** 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.525s | 301M |
| Rust (whole-image) | 3.111s | 301M |
| Rust (chunked-parallel) | 3.306s | 301M |
| Rust (fixed-point) | 2.621s | 191M |
| Rust (direct-gdal) | 2.588s | N/A |
| Rust (parallel-io) | 2.235s | 191M |
| GDAL calc | 13.355s | 299M |
| GRASS GIS | 8.307s | 4.0K |
| Zig (SIMD) | 2.592s | 191M |
