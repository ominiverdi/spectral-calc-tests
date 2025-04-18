# Spectral Math Function Templates for CLI Library

This document outlines reusable mathematical function templates for a spectral arithmetic CLI tool. These functions are commonly used in remote sensing to compute indices from satellite imagery. Each function is intended to be mapped to a CLI command in the form:

```bash
spectra-math <function_name> a=/path/to/input1.tif b=/path/to/input2.tif [params] o=/path/to/output.tif
```

---

## ✅ Function Templates

### 1. `ndi(a, b)`
**Normalized Difference Index**
```math
NDI(a, b) = \frac{a - b}{a + b}
```
- Used for: NDVI, NDWI, NDBI, etc.
- Output is normalized between -1 and 1.
- **Example:**
```bash
spectra-math ndi a=nir.tif b=red.tif o=ndvi.tif
```

---

### 2. `ratio(a, b)`
**Simple Ratio**
```math
RATIO(a, b) = \frac{a}{b}
```
- Common for mineral detection, water/soil moisture.
- **Example:**
```bash
spectra-math ratio a=swir.tif b=nir.tif o=swir_nir_ratio.tif
```

---

### 3. `diff(a, b)`
**Difference**
```math
DIFF(a, b) = a - b
```
- Often used in change detection (before/after).
- **Example:**
```bash
spectra-math diff a=before.tif b=after.tif o=change.tif
```

---

### 4. `sum(a, b)`
**Sum**
```math
SUM(a, b) = a + b
```
- Useful for albedo, brightness composite.
- **Example:**
```bash
spectra-math sum a=red.tif b=green.tif o=sum_rg.tif
```

---

### 5. `index3(a, b, c)`
**Three-Band Normalized Index**
```math
INDEX3(a, b, c) = \frac{a - (b + c)}{a + b + c}
```
- Used for: Urban Index, false-color composites.
- **Example:**
```bash
spectra-math index3 a=swir.tif b=nir.tif c=blue.tif o=urban_index.tif
```

---

### 6. `evi(nir, red, blue)`
**Enhanced Vegetation Index**
```math
EVI = 2.5 \cdot \frac{nir - red}{nir + 6 \cdot red - 7.5 \cdot blue + 1}
```
- Reduces atmospheric and canopy background noise.
- **Example:**
```bash
spectra-math evi a=nir.tif b=red.tif c=blue.tif o=evi.tif
```

---

### 7. `savi(nir, red, l=0.5)`
**Soil Adjusted Vegetation Index**
```math
SAVI = \frac{(1 + L)(nir - red)}{nir + red + L}
```
- Reduces soil brightness impact.
- `L` is an adjustment constant (typically 0.5).
- **Example:**
```bash
spectra-math savi a=nir.tif b=red.tif l=0.5 o=savi.tif
```

---

### 8. `tri_band_sum(a, b, c)`
**Three-Band Sum**
```math
TRI_BAND_SUM(a, b, c) = a + b + c
```
- Used for: visual composites, brightness, albedo.
- **Example:**
```bash
spectra-math tri_band_sum a=red.tif b=green.tif c=blue.tif o=composite_sum.tif
```

---

## 🧰 Notes
- All functions should implement safeguards against division by zero.
- Input files should be float32-compatible.
- Output should maintain the geospatial profile of the first input band.

---

This structure allows for a clean, scalable CLI for spectral analysis and is easily extensible with more indices as needed.

