# Fill gaps in motion capture data

Fills NA gaps in one or more position assays of a PhysioExperiment
object using interpolation. Gaps larger than `max_gap` are left as NA.

## Usage

``` r
fillGaps(pe, method = c("spline", "linear"), max_gap = 50, assay_names = NULL)
```

## Arguments

- pe:

  A PhysioExperiment object

- method:

  Interpolation method: `"linear"` uses
  [`approx`](https://rdrr.io/r/stats/approxfun.html), `"spline"` uses
  [`smooth.spline`](https://rdrr.io/r/stats/smooth.spline.html)

- max_gap:

  Maximum gap size (in samples) to fill. Gaps larger than this are left
  as NA. Set to `Inf` to fill all gaps.

- assay_names:

  Character vector of assay names to fill. If `NULL` (default), fills
  all position assays that are present (position_x, position_y,
  position_z, keypoint_x, keypoint_y).

## Value

PhysioExperiment with filled assays (modified in place)

## References

Federolf PA (2013). "A novel approach to solve the 'missing marker
problem' in marker-based motion analysis that does not require
additional assumptions about the biodynamic model." Journal of
Biomechanics, 46(13), 2173-2178.

## See also

[`detectGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md),
[`reportGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/reportGaps.md),
[`fillGapsLinear()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsLinear.md),
[`fillGapsSpline()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsSpline.md)

## Examples

``` r
pe <- PhysioCore::PhysioExperiment(
  assays = S4Vectors::SimpleList(
    position_x = matrix(c(1, NA, NA, 4, 5), ncol = 1),
    position_y = matrix(c(10, NA, NA, 40, 50), ncol = 1)
  ),
  colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
  samplingRate = 120
)
pe_filled <- fillGaps(pe, method = "linear", max_gap = 50)
```
