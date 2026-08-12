# Dimensionality Reduction for Biomechanics

Functions for dimensionality reduction and visualization of
high-dimensional biomechanical waveform data including PCA, UMAP, and
t-SNE. Extract waveform features for dimensionality reduction

## Usage

``` r
extractWaveformFeatures(x, features = c("statistical", "shape"), n_points = 50)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- features:

  Character vector of features to extract: "raw" (flattened waveform),
  "statistical" (summary stats), "frequency" (spectral features),
  "shape" (curve characteristics).

- n_points:

  For "raw", number of points to resample to.

## Value

A matrix (observations x features) suitable for PCA/UMAP.

## Details

Extracts summary features from waveforms for use with standard
dimensionality reduction methods.

Feature types:

- raw: The raw waveform resampled to n_points

- statistical: Mean, SD, min, max, range, skewness, kurtosis

- frequency: Dominant frequency, spectral centroid, bandwidth

- shape: Peaks, zero crossings, area under curve

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md),
[`waveformUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformUMAP.md),
[`waveformTSNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformTSNE.md)

## Examples

``` r
# Extract features from gait data
set.seed(123)
data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
features <- extractWaveformFeatures(data, features = c("statistical", "shape"))
```
