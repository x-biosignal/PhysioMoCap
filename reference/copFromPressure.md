# Derive center of pressure from a pressure movie

Computes the pressure-weighted centroid at each frame. Grid columns
define the mediolateral (`cop_x`) direction and rows define the
anteroposterior (`cop_y`) direction, matching
[`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md)
and
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md).

## Usage

``` r
copFromPressure(pm, contact_threshold = 0)
```

## Arguments

- pm:

  A `pressure_movie`.

- contact_threshold:

  Pressure threshold in kPa. Values at or below the threshold do not
  contribute to force or center of pressure.

## Value

A data frame with `time`, `cop_x`, `cop_y`, `total_force`, and
`contact_area`. CoP coordinates are in mm and force is in N.

## References

Pataky TC (2012). Spatial resolution in plantar pressure measurement
revisited. *Journal of Biomechanics*, 45:2116-2124.

## See also

[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md),
[`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md)

## Examples

``` r
x <- array(0, c(3, 3, 2))
x[2, 3, ] <- 100
copFromPressure(pressureMovie(x, 100, dx = 5, dy = 5))
#>   time cop_x cop_y total_force contact_area
#> 1 0.00  12.5   7.5         2.5           25
#> 2 0.01  12.5   7.5         2.5           25
```
