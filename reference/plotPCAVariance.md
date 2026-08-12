# Plot PCA variance explained

Creates a scree plot showing variance explained by each PC.

## Usage

``` r
plotPCAVariance(x, n_components = NULL)
```

## Arguments

- x:

  A waveform_pca object.

- n_components:

  Number of components to show.

## Value

A ggplot object.

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md),
[`plotPCAScatter()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAScatter.md),
[`plotUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotUMAP.md)
