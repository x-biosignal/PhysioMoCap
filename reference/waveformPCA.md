# PCA for waveform data

Performs Principal Component Analysis on waveform data, either using
extracted features or raw waveforms.

## Usage

``` r
waveformPCA(
  x,
  method = c("features", "raw"),
  features = c("statistical", "shape"),
  n_components = 10,
  scale = TRUE
)
```

## Arguments

- x:

  A PhysioExperiment object or matrix.

- method:

  Feature extraction method: "features" or "raw".

- features:

  If method = "features", which features to extract.

- n_components:

  Number of PCs to retain.

- scale:

  Logical; scale features to unit variance.

## Value

A list of class "waveform_pca" containing:

- scores:

  PC scores (observations x components)

- loadings:

  PC loadings (features x components)

- variance_explained:

  Variance explained by each PC

- cumulative_variance:

  Cumulative variance

- center:

  Feature means

- scale:

  Feature SDs (if scaled)

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`extractWaveformFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractWaveformFeatures.md),
[`waveformUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformUMAP.md),
[`plotPCAScatter()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAScatter.md),
[`plotPCAVariance()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAVariance.md)

## Examples

``` r
# PCA on gait features
set.seed(123)
data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
pca_result <- waveformPCA(data, method = "features")
plotPCAScatter(pca_result)
```
