# Linear interpolation for a single vector

Fills NA values in a numeric vector using linear interpolation via
[`approx`](https://rdrr.io/r/stats/approxfun.html).

## Usage

``` r
fillGapsLinear(x)
```

## Arguments

- x:

  Numeric vector potentially containing NAs

## Value

Numeric vector with NAs filled by linear interpolation. Leading and
trailing NAs (outside the range of valid data) remain as NA.

## References

Federolf PA (2013). "A novel approach to solve the 'missing marker
problem' in marker-based motion analysis that does not require
additional assumptions about the biodynamic model." Journal of
Biomechanics, 46(13), 2173-2178.

## See also

[`fillGapsSpline()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsSpline.md),
[`fillGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGaps.md),
[`detectGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md)

## Examples

``` r
x <- c(1, NA, NA, 4, 5, NA, 7)
fillGapsLinear(x)
#> [1] 1 2 3 4 5 6 7
```
