# Detect contact windows for one or more force plates

Identifies threshold-based contact windows from vertical GRF signals.

## Usage

``` r
detectForcePlateContacts(vgrf, threshold = 20, sampling_rate = NULL)
```

## Arguments

- vgrf:

  Numeric vector or matrix of vertical GRF (rows = time, columns =
  plates/channels).

- threshold:

  Contact threshold in force units.

- sampling_rate:

  Optional sampling rate in Hz. If provided, durations are returned in
  seconds.

## Value

A data.frame with one row per detected contact and columns: `plate`,
`stance`, `onset`, `offset`, `duration_samples`, `duration_s`, and
`peak_force`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for comprehensive force plate analysis,
[`analyzeForcePlatePE()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlatePE.md)
for PhysioExperiment-based analysis.

## Examples

``` r
v <- cbind(
  fp1 = c(rep(0, 100), rep(500, 200), rep(0, 100)),
  fp2 = c(rep(0, 200), rep(700, 100), rep(0, 100))
)
detectForcePlateContacts(v, threshold = 20, sampling_rate = 1000)
#>   plate stance onset offset duration_samples duration_s peak_force
#> 1   fp1      1   101    300              200        0.2        500
#> 2   fp2      1   201    300              100        0.1        700
```
