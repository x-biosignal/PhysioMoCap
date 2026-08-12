# Resample a single numeric vector

Resamples a numeric vector from one sampling rate to another using
interpolation.

## Usage

``` r
resampleVector(x, from_rate, to_rate, method = c("linear", "spline"))
```

## Arguments

- x:

  Numeric vector to resample.

- from_rate:

  Original sampling rate in Hz.

- to_rate:

  Target sampling rate in Hz.

- method:

  Interpolation method: "linear" uses
  [`approx`](https://rdrr.io/r/stats/approxfun.html), "spline" uses
  [`spline`](https://rdrr.io/r/stats/splinefun.html).

## Value

A numeric vector resampled at the target rate.

## References

Oppenheim AV, Willsky AS, Nawab SH (1997). "Signals and Systems." 2nd
ed. Prentice Hall.

## See also

[`resampleSignal()`](https://x-biosignal.github.io/PhysioMoCap/reference/resampleSignal.md)
for resampling PhysioExperiment objects,
[`synchronizeSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/synchronizeSignals.md)
for synchronizing multiple signals.

## Examples

``` r
# Resample a 100Hz signal to 200Hz
x <- sin(seq(0, 2 * pi, length.out = 100))
x_up <- resampleVector(x, from_rate = 100, to_rate = 200)
length(x_up)  # 200
#> [1] 199
```
