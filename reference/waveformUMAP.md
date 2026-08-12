# UMAP embedding for waveform data

Performs UMAP dimensionality reduction on waveform data for
visualization. Requires the uwot package.

## Usage

``` r
waveformUMAP(
  x,
  n_neighbors = 15,
  n_components = 2,
  min_dist = 0.1,
  metric = "euclidean",
  features = c("statistical", "shape"),
  use_pca = TRUE,
  n_pca = 30,
  seed = NULL
)
```

## Arguments

- x:

  A PhysioExperiment object, matrix, or waveform_pca result.

- n_neighbors:

  Number of neighbors for UMAP.

- n_components:

  Number of UMAP dimensions (usually 2).

- min_dist:

  Minimum distance parameter.

- metric:

  Distance metric: "euclidean", "cosine", "manhattan".

- features:

  If x is waveform data, features to extract.

- use_pca:

  Logical; pre-reduce with PCA (recommended for high-dim).

- n_pca:

  Number of PCA components to use as input.

- seed:

  Random seed for reproducibility.

## Value

A list of class "waveform_umap" containing:

- embedding:

  UMAP coordinates (observations x n_components)

- n_obs:

  Number of observations

- params:

  UMAP parameters used

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md),
[`waveformTSNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformTSNE.md),
[`plotUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotUMAP.md),
[`extractWaveformFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractWaveformFeatures.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# UMAP on gait data
data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
umap_result <- waveformUMAP(data, n_neighbors = 15)
plotUMAP(umap_result)
} # }
```
