# Low-pass filter ground reaction force data

Applies low-pass filtering to force-plate signals. By default this uses
a zero-phase Butterworth filter (requires the `signal` package). If
`signal` is not available, the function falls back to a moving-average
filter.

## Usage

``` r
filterGRF(
  x,
  sampling_rate,
  cutoff = 20,
  order = 4,
  method = c("butterworth", "moving_average")
)
```

## Arguments

- x:

  Numeric vector or matrix (time x channels).

- sampling_rate:

  Sampling rate in Hz.

- cutoff:

  Low-pass cutoff frequency in Hz.

- order:

  Butterworth filter order.

- method:

  Filtering method: `"butterworth"` or `"moving_average"`.

## Value

Filtered data with the same dimensions as `x`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md)
for general Butterworth filtering,
[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for comprehensive force plate analysis.

## Examples

``` r
sr <- 1000
t <- seq(0, 1, length.out = sr)
x <- sin(2 * pi * 10 * t) + 0.2 * sin(2 * pi * 150 * t)
y <- filterGRF(x, sampling_rate = sr, cutoff = 25)
```
