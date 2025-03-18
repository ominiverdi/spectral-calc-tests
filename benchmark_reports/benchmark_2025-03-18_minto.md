# GeoSpectraCalc Benchmark Results
- **Date:** Tue Mar 18 12:39:27 PM CET 2025
- **System:** minto
- **CPU:** Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
- **Cores:** 20 logical, 10 physical
- **Memory:** 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.479s | 301M |
| Rust (whole-image) | 3.150s | 301M |
| Rust (chunked-parallel) | 3.360s | 301M |
| Rust (fixed-point) | 2.566s | 191M |
| Rust (direct-gdal) | 2.586s | 191M |
| GDAL calc | 12.720s | 299M |
| GRASS GIS | 8.106s | 4.0K |
