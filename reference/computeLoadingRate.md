# Compute vertical loading rate from GRF

Detects stance phases from a vertical GRF signal and computes loading
rate from initial contact to peak force for each stance.

## Usage

``` r
computeLoadingRate(
  vgrf,
  sampling_rate,
  threshold = 20,
  method = c("instantaneous", "average")
)
```

## Arguments

- vgrf:

  Numeric vector or matrix of vertical GRF values.

- sampling_rate:

  Sampling rate in Hz.

- threshold:

  Contact threshold in force units.

- method:

  Loading-rate method: `"instantaneous"` (max slope) or `"average"`
  (peak rise over time-to-peak).

## Value

For vector input: a data.frame with one row per stance. For matrix
input: same data.frame with an added `channel` column.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for comprehensive force plate analysis,
[`computeImpulse()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeImpulse.md)
for impulse computation.

## Examples

``` r
grf <- c(rep(0, 100), seq(0, 800, length.out = 150),
         seq(800, 0, length.out = 150), rep(0, 100))
computeLoadingRate(grf, sampling_rate = 1000)
#>   stance onset peak time_to_peak peak_force loading_rate
#> 1      1   105  250        0.145        800     5369.128
```
