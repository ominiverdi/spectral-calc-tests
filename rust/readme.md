# GeoSpectraCalc

A high-performance command-line tool for calculating spectral indices from remote sensing data, written in Rust.

## Features

- Fast and memory-efficient processing using Rust and parallel computing
- Support for common spectral indices:
  - NDVI (Normalized Difference Vegetation Index)
  - EVI (Enhanced Vegetation Index)
  - NDWI (Normalized Difference Water Index)
  - NDBI (Normalized Difference Built-up Index)
  - SAVI (Soil Adjusted Vegetation Index)
- Memory-efficient processing in chunks
- Proper GeoTIFF output with compression and tiling

## Installation

### Prerequisites

- Rust (1.64+)
- GDAL (3.0+)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/geo-spectra-calc.git
   cd geo-spectra-calc
   ```

2. Set the GDAL environment variable:
   ```bash
   export GDAL_DYNAMIC=YES
   ```

3. Build the project:
   ```bash
   cargo build --release
   ```

## Usage

```bash
./target/release/geo-spectra-calc --index INDEX --output OUTPUT [OPTIONS]
```

### Example Commands

Calculate NDVI:
```bash
./target/release/geo-spectra-calc --index NDVI \
  --nir "path/to/nir_band.tif" \
  --red "path/to/red_band.tif" \
  --output ndvi_result.tif
```

Calculate EVI:
```bash
./target/release/geo-spectra-calc --index EVI \
  --nir "path/to/nir_band.tif" \
  --red "path/to/red_band.tif" \
  --blue "path/to/blue_band.tif" \
  --output evi_result.tif
```

Calculate NDWI:
```bash
./target/release/geo-spectra-calc --index NDWI \
  --green "path/to/green_band.tif" \
  --nir "path/to/nir_band.tif" \
  --output ndwi_result.tif
```

### Command Line Options

```
OPTIONS:
  -i, --index INDEX      Spectral index to calculate (NDVI, EVI, NDWI, NDBI, SAVI)
  -o, --output FILE      Output file path
  --nir FILE             Path to NIR band
  --red FILE             Path to RED band
  --green FILE           Path to GREEN band
  --blue FILE            Path to BLUE band
  --swir FILE            Path to SWIR band
  --scale VALUE          Scale factor to convert DN to reflectance [default: 10000.0]
  --nodata VALUE         NoData value for output [default: -999.0]
  --chunk-size SIZE      Processing chunk size [default: 2048]
  --l-factor VALUE       L factor for SAVI [default: 0.5]
  -v, --verbose          Print verbose output
  -h, --help             Print help
  -V, --version          Print version
```

## Performance Considerations

- The default chunk size of 2048 is optimized for systems with 8GB+ of RAM. For systems with less RAM, decrease the chunk size.
- For large files, consider using the `--chunk-size` option to adjust memory usage.

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.