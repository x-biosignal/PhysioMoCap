# Bland-Altman agreement plot

Draws the Bland-Altman difference-vs-mean scatter that
[`blandAltman`](https://x-biosignal.github.io/PhysioCore//reference/blandAltman.html)
only computes: the bias (mean difference), the upper/lower limits of
agreement (LoA), and shaded confidence bands for the bias and each LoA.
The numerics come from
[`blandAltman()`](https://x-biosignal.github.io/PhysioCore//reference/blandAltman.html)
so the plotted reference lines are single-sourced and cannot drift from
the computed statistics.

## Usage

``` r
plotBlandAltman(
  x,
  y,
  confidence = 0.95,
  proportional_bias = FALSE,
  units = NULL,
  colorblind = TRUE
)
```

## Arguments

- x, y:

  Numeric vectors of paired measurements (two methods, or two time
  points). Must be the same length with at least 2 pairs (validated by
  [`blandAltman()`](https://x-biosignal.github.io/PhysioCore//reference/blandAltman.html)).

- confidence:

  Confidence level for the limits of agreement and the shaded confidence
  bands (default 0.95).

- proportional_bias:

  Logical. If `TRUE`, model the bias and LoA as linear in the mean
  (Bland-Altman regression): the bias line is the OLS fit of the
  difference on the mean with a shaded fitted-line confidence band, and
  the LoA are the fit \\\pm z \cdot s\_{resid}\\. Use when the
  difference scales with magnitude. Requires at least 3 pairs (the
  regression residual variance is undefined at n = 2). Default `FALSE`
  (constant bias/LoA).

- units:

  Optional measurement unit appended to the axis labels.

- colorblind:

  Logical; if `TRUE` (default) use the ecosystem colorblind-safe palette
  ([`physioPalette`](https://x-biosignal.github.io/PhysioCore//reference/physioPalette.html)).

## Value

A `ggplot` object.

## References

Bland JM, Altman DG (1986). Statistical methods for assessing agreement
between two methods of clinical measurement. *Lancet*, 327(8476),
307-310.
[doi:10.1016/S0140-6736(86)90837-8](https://doi.org/10.1016/S0140-6736%2886%2990837-8)

## See also

[`PhysioCore::blandAltman()`](https://x-biosignal.github.io/PhysioCore//reference/blandAltman.html)
for the underlying statistics.

## Examples

``` r
# \donttest{
set.seed(1)
m1 <- rnorm(30, 50, 10)
m2 <- m1 + rnorm(30, 0, 3)
plotBlandAltman(m1, m2)

plotBlandAltman(m1, m2, proportional_bias = TRUE, units = "deg")

# }
```
