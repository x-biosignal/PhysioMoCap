# Plot PCA scatter

Creates a scatter plot of PCA scores.

## Usage

``` r
plotPCAScatter(x, components = c(1, 2), groups = NULL, labels = NULL)
```

## Arguments

- x:

  A waveform_pca object.

- components:

  Which PCs to plot (length 2).

- groups:

  Optional grouping factor for coloring.

- labels:

  Optional labels for points.

## Value

A ggplot object.

## References

van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
Journal of Machine Learning Research, 9, 2579-2605.

## See also

[`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md),
[`plotPCAVariance()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAVariance.md),
[`plotUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotUMAP.md)
