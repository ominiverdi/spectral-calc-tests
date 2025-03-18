# GeoSpectraCalc Benchmark Results
- **Date:** Tue Mar 18 07:55:05 PM CET 2025
- **System:** minto
- **CPU:** Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
- **Cores:** 20 logical, 10 physical
- **Memory:** 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.577s | 301M |
| Rust (whole-image) | 3.176s | 301M |
| Rust (chunked-parallel) | 3.360s | 301M |
| Rust (fixed-point) | 2.600s | 191M |
| Rust (direct-gdal) | 2.585s | N/A |
| GDAL calc | 13.832s | 299M |
| GRASS GIS | 8.399s | 4.0K |
