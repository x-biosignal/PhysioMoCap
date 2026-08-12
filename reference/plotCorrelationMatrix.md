# Plot correlation matrix heatmap

Creates a heatmap visualization of a correlation matrix with optional
clustering and significance masking.

## Usage

``` r
plotCorrelationMatrix(
  x,
  method = "pearson",
  cluster = TRUE,
  show_values = TRUE,
  show_significance = FALSE,
  alpha = 0.05,
  colors = c("#B2182B", "white", "#2166AC"),
  title = "Correlation Matrix"
)
```

## Arguments

- x:

  A correlation matrix, data.frame, or PhysioExperiment.

- method:

  If x is data, correlation method: "pearson", "spearman", "kendall".

- cluster:

  Logical; apply hierarchical clustering to reorder.

- show_values:

  Logical; display correlation values in cells.

- show_significance:

  Logical; mask non-significant correlations.

- alpha:

  Significance threshold for masking.

- colors:

  Color palette (low, mid, high).

- title:

  Plot title.

## Value

A ggplot object.

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

## See also

[`plotEffectSizeForest()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotEffectSizeForest.md)
for forest plots of effect sizes,
[`plotWaveformComparison()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotWaveformComparison.md)
for comparing waveform patterns across groups.

## Examples

``` r
# Correlation matrix of joint angles
set.seed(123)
data <- data.frame(
  Hip = rnorm(100),
  Knee = rnorm(100),
  Ankle = rnorm(100)
)
data$Knee <- data$Hip * 0.7 + rnorm(100, 0, 0.5)  # Correlated

plotCorrelationMatrix(data)
```
