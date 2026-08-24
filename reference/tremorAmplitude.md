# Band-limited tremor amplitude (RMS)

Band-pass filters the signal to the tremor band and returns its
root-mean- square amplitude (in the units of the input signal).

## Usage

``` r
tremorAmplitude(signal, sampling_rate, band = c(3, 12), order = 4)
```

## Arguments

- signal:

  Numeric movement signal.

- sampling_rate:

  Sampling rate in Hz.

- band:

  Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).

- order:

  Butterworth filter order (default 4).

## Value

A list with `rms` and the `band` used.

## See also

[`tremorSpectrum()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorSpectrum.md),
[`tremorMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorMetrics.md)

## Examples

``` r
fs <- 100; t <- seq(0, 20, by = 1 / fs)
tremorAmplitude(2 * sin(2 * pi * 5 * t), fs)$rms   # ~ 2 / sqrt(2)
#> [1] 1.411585
```
