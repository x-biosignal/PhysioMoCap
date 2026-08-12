# Simple moving average filter

Applies a symmetric moving average for quick smoothing of signal data.
Uses [`stats::filter()`](https://rdrr.io/r/stats/filter.html) internally
with equal weights.

## Usage

``` r
movingAverage(x, window = 5)
```

## Arguments

- x:

  A numeric vector or matrix (time x channels).

- window:

  Window size for the moving average (default: 5). Will be coerced to an
  odd integer.

## Value

Smoothed data with the same dimensions as `x`. Edge values where the
full window cannot be applied are set to NA.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md)
for Butterworth low-pass filtering,
[`savgolFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/savgolFilter.md)
for Savitzky-Golay polynomial smoothing.

## Examples

``` r
# Smooth a noisy signal
x <- sin(seq(0, 4 * pi, length.out = 200)) + rnorm(200, sd = 0.3)
x_smooth <- movingAverage(x, window = 7)
```
