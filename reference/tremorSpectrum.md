# Tremor power spectrum and dominant frequency

Estimates the power spectrum of a movement signal (Welch periodogram)
and summarises the tremor within a frequency band: the dominant
frequency, its peak power, absolute and relative in-band power, the
half-power bandwidth (peak sharpness) and the first-harmonic ratio.

## Usage

``` r
tremorSpectrum(
  signal,
  sampling_rate,
  band = c(3, 12),
  detrend = TRUE,
  seg_sec = NULL
)
```

## Arguments

- signal:

  Numeric vector: one axis, or the vector magnitude, of an accelerometer
  / gyroscope / displacement signal (gravity removed for raw
  accelerometry).

- sampling_rate:

  Sampling rate in Hz.

- band:

  Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).

- detrend:

  Remove the signal mean before spectral estimation (default `TRUE`;
  each Welch segment is also demeaned).

- seg_sec:

  Optional Welch segment length in seconds (default: about an eighth of
  the record, rounded to a power of two).

## Value

A list: `dominant_freq_hz`, `peak_power`, `band_power_abs`,
`band_power_rel` (in-band / total power), `half_power_bw_hz`,
`harmonic_ratio` (power at 2\*f0 / power at f0), and the `freq` / `psd`
vectors.

## See also

[`tremorAmplitude()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorAmplitude.md),
[`tremorMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorMetrics.md)

## Examples

``` r
fs <- 100; t <- seq(0, 20, by = 1 / fs)
x <- 2 * sin(2 * pi * 5 * t)            # a 5 Hz, amplitude-2 tremor
tremorSpectrum(x, fs)$dominant_freq_hz
#> [1] 5.078125
```
