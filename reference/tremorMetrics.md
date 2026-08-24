# Tremor metrics (frequency + amplitude, with a task tag)

Combines
[`tremorSpectrum()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorSpectrum.md)
and
[`tremorAmplitude()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorAmplitude.md)
into a single tremor summary, tagged with the recording condition. The
rest / postural / kinetic distinction is task-context metadata supplied
by the caller (the segment recorded under that condition), not a
separate algorithm.

## Usage

``` r
tremorMetrics(
  signal,
  sampling_rate,
  condition = c("rest", "postural", "kinetic"),
  band = c(3, 12),
  ...
)
```

## Arguments

- signal:

  Numeric movement signal (one axis or magnitude).

- sampling_rate:

  Sampling rate in Hz.

- condition:

  Recording condition: `"rest"`, `"postural"` or `"kinetic"`.

- band:

  Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).

- ...:

  Passed to
  [`tremorSpectrum()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorSpectrum.md).

## Value

An S3 `tremor_metrics` list: `dominant_freq_hz`, `band_power_abs`,
`band_power_rel`, `rms_amplitude`, `half_power_bw_hz`, `harmonic_ratio`,
`condition`, `band`, `sampling_rate`.

## See also

[`tremorSpectrum()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorSpectrum.md),
[`tremorAmplitude()`](https://x-biosignal.github.io/PhysioMoCap/reference/tremorAmplitude.md)

## Examples

``` r
fs <- 100; t <- seq(0, 20, by = 1 / fs)
tremorMetrics(1.5 * sin(2 * pi * 6 * t), fs, condition = "postural")
#> Tremor metrics (postural, 3-12 Hz)
#>   dominant frequency : 5.86 Hz
#>   RMS amplitude      : 1.059
#>   in-band power      : 1.125 (100% of total)
#>   half-power bandwidth: 0.39 Hz | harmonic ratio: 0.000
```
