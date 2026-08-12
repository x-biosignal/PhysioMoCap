# Spline interpolation for a single vector

Fills NA values in a numeric vector using smooth spline interpolation
via [`smooth.spline`](https://rdrr.io/r/stats/smooth.spline.html).

## Usage

``` r
fillGapsSpline(x, spar = NULL)
```

## Arguments

- x:

  Numeric vector potentially containing NAs

- spar:

  Smoothing parameter passed to
  [`smooth.spline`](https://rdrr.io/r/stats/smooth.spline.html). If
  `NULL` (default), the smoothing parameter is chosen automatically.

## Value

Numeric vector with NAs filled by spline interpolation. Leading and
trailing NAs (outside the range of valid data) remain as NA.

## References

Federolf PA (2013). "A novel approach to solve the 'missing marker
problem' in marker-based motion analysis that does not require
additional assumptions about the biodynamic model." Journal of
Biomechanics, 46(13), 2173-2178.

## See also

[`fillGapsLinear()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsLinear.md),
[`fillGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGaps.md),
[`detectGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md)

## Examples

``` r
x <- c(1, NA, NA, 4, 5, NA, 7)
fillGapsSpline(x)
#> [1] 1 2 3 4 5 6 7
```
