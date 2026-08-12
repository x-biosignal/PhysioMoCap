# Compute vertical impulse from GRF

Integrates vertical force over detected stance phases using trapezoidal
integration.

## Usage

``` r
computeImpulse(
  force,
  sampling_rate,
  threshold = 20,
  subtract_threshold = FALSE
)
```

## Arguments

- force:

  Numeric vector or matrix of vertical force values.

- sampling_rate:

  Sampling rate in Hz.

- threshold:

  Contact threshold in force units.

- subtract_threshold:

  Logical; if `TRUE`, subtracts `threshold` before integrating each
  stance (negative values clipped to zero).

## Value

For vector input: data.frame with one row per stance and columns
including `impulse` (force\*time units). For matrix input: same
structure plus `channel`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for comprehensive force plate analysis,
[`computeLoadingRate()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeLoadingRate.md)
for loading rate computation.

## Examples

``` r
grf <- c(rep(0, 50), rep(600, 100), rep(0, 50))
computeImpulse(grf, sampling_rate = 1000)
#>   stance onset offset duration_s impulse
#> 1      1    51    150      0.099    59.4
```
