# t-SNE embedding for waveform data

Performs t-SNE dimensionality reduction on waveform data. Requires the
Rtsne package.

## Usage

``` r
waveformTSNE(
  x,
  perplexity = 30,
  n_components = 2,
  max_iter = 1000,
  features = c("statistical", "shape"),
  use_pca = TRUE,
  n_pca = 30,
  seed = NULL
)
```

## Arguments

- x:

  A PhysioExperiment object, matrix, or waveform_pca result.

- perplexity:

  t-SNE perplexity parameter.

- n_components:

  Number of dimensions (usually 2).

- max_iter:

  Maximum iterations.

- features:

  If x is waveform data, features to extract.

- use_pca:

  Logical; pre-reduce with PCA.

- n_pca:

  Number of PCA components.

- seed:

  Random seed.

## Value

A list of class "waveform_tsne" containing:

- embedding:

  t-SNE coordinates

- n_obs:

  Number of observations

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md),
[`waveformUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformUMAP.md),
[`extractWaveformFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractWaveformFeatures.md)
