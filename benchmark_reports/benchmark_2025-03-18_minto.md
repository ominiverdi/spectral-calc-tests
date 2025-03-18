# GeoSpectraCalc Benchmark Results
Date: Tue Mar 18 12:36:05 PM CET 2025
System: minto
CPU: Intel(R) Core(TM) i9-10900 CPU @ 2.80GHz
Cores: 20 logical, 10 physical
Memory: 62 GB RAM
## Results
| Implementation | Runtime | Output Size |
|----------------|---------|------------|
| C | 3.559s | 301M |
| Rust (whole-image) | 3.150s | 301M |
| Rust (chunked-parallel) | 3.315s | 301M |
| Rust (fixed-point) | 2.595s | 191M |
| Rust (direct-gdal) | 2.602s | 191M |
| GDAL calc | 13.020s | 299M |
| GRASS GIS | 8.044s | 4.0K |
