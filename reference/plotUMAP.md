# Plot UMAP embedding

Creates a scatter plot of UMAP embedding.

## Usage

``` r
plotUMAP(x, groups = NULL, labels = NULL)
```

## Arguments

- x:

  A waveform_umap object.

- groups:

  Optional grouping factor.

- labels:

  Optional point labels.

## Value

A ggplot object.

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformUMAP.md),
[`plotPCAScatter()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAScatter.md),
[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md)
