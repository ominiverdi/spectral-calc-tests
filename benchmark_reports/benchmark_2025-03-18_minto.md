# GeoSpectraCalc Benchmark Results
- **Date:** Tue Mar 18 09:33:13 PM CET 2025
- **System:** minto
- **CPU:** Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
- **Cores:** 20 logical, 10 physical
- **Memory:** 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.520s | 301M |
| Rust (whole-image) | 3.176s | 301M |
| Rust (chunked-parallel) | 3.407s | 301M |
| Rust (fixed-point) | 2.607s | 191M |
| Rust (direct-gdal) | 2.674s | N/A |
| GDAL calc | 13.219s | 299M |
| GRASS GIS | 8.202s | 4.0K |
| Zig (SIMD) | 2.616s | 191M |
