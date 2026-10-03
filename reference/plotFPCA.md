# Plot fPCA results

Visualizes functional PCA results including loadings and variance
explained.

## Usage

``` r
plotFPCA(
  x,
  type = c("loadings", "variance", "scores", "all"),
  components = 1:4,
  time_axis = NULL
)
```

## Arguments

- x:

  An fpca_result object.

- type:

  Plot type: "loadings", "variance", "scores", or "all".

- components:

  Which components to plot.

- time_axis:

  Optional time axis values.

## Value

A ggplot object (or list of plots for type = "all").

## References

Ramsay JO, Silverman BW (2005). "Functional Data Analysis." 2nd ed.
Springer.

## See also

[`fPCA()`](https://x-biosignal.r-universe.dev/PhysioExperiment/reference/fPCA.html)
for computing fPCA results,
[`reconstructFPCA()`](https://x-biosignal.r-universe.dev/PhysioExperiment/reference/reconstructFPCA.html)
for waveform reconstruction.

## Examples

``` r
set.seed(1)
curves <- matrix(rep(sin(seq(0, pi, length.out = 101)), 20) +
                   rnorm(101 * 20, 0, 0.1), 101, 20)
fp <- fPCA(curves)
plotFPCA(fp, type = "variance")
```
