# Apply a Butterworth filter to numeric data

Designs a Butterworth IIR filter and applies it using zero-phase
filtering (forward-backward) to avoid phase distortion.

## Usage

``` r
butterworthFilter(
  x,
  cutoff,
  sampling_rate,
  type = c("lowpass", "highpass", "bandpass", "bandstop"),
  order = 4
)
```

## Arguments

- x:

  A numeric vector or matrix (time x channels).

- cutoff:

  Cutoff frequency in Hz. A single value for "lowpass" or "highpass"; a
  length-2 vector `c(low, high)` for "bandpass" or "bandstop".

- sampling_rate:

  Sampling rate in Hz.

- type:

  Filter type: "lowpass", "highpass", "bandpass", or "bandstop".

- order:

  Filter order (default: 4).

## Value

Filtered data with the same dimensions as `x`.

## Details

Requires the signal package. NAs in the input are temporarily
interpolated before filtering and restored afterward.

## References

Butterworth S (1930). "On the Theory of Filter Amplifiers." Wireless
Engineer, 7, 536-541.

## See also

[`filterSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterSignals.md)
for filtering PhysioExperiment objects,
[`savgolFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/savgolFilter.md)
for Savitzky-Golay polynomial smoothing.

## Examples

``` r
if (requireNamespace("signal", quietly = TRUE)) {
  x <- sin(2 * pi * 2 * seq(0, 1, length.out = 120)) + rnorm(120, 0, 0.1)
  xf <- butterworthFilter(x, cutoff = 6, sampling_rate = 120)
  length(xf)
}
#> [1] 120
```
