# Detect the spastic catch on a single passive stretch

Locates the Tardieu "catch" on one passive-stretch joint-angle trace and
returns the catch angle (R1). The catch is detected from a reflex EMG
burst (envelope crossing a baseline mean + `threshold_sd` \* SD
threshold), from a velocity arrest (angular velocity dropping below
`catch_fraction` of its peak after the fastest stretch), or from both.

## Usage

``` r
tardieuStretch(
  angle,
  emg = NULL,
  sampling_rate,
  emg_sampling_rate = sampling_rate,
  onset = c("emg", "velocity", "both"),
  baseline_sec = 0.5,
  threshold_sd = 3,
  catch_fraction = 0.5,
  envelope_ms = 50
)
```

## Arguments

- angle:

  Numeric joint-angle trace over the stretch (degrees; increasing as the
  joint is stretched).

- emg:

  Optional EMG of the stretched muscle (numeric); enables the EMG
  reflex-onset trigger.

- sampling_rate:

  Angle sampling rate (Hz).

- emg_sampling_rate:

  EMG sampling rate (Hz); the EMG is resampled onto the angle time base
  with
  [`alignEMGtoMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/alignEMGtoMoCap.md).
  Default = `sampling_rate`.

- onset:

  Catch trigger: `"emg"`, `"velocity"` or `"both"` (EMG-preferred,
  velocity fallback).

- baseline_sec:

  Baseline window (s) for the EMG threshold (default 0.5).

- threshold_sd:

  EMG onset threshold in baseline SDs (default 3).

- catch_fraction:

  Velocity-arrest fraction of peak velocity (default 0.5).

- envelope_ms:

  EMG RMS-envelope window in ms (default 50).

## Value

An S3 `tardieu_stretch` list: `catch_angle` (R1), `catch_index`,
`catch_velocity`, `peak_velocity`, `rom_max`/`rom_min`,
`reflex_latency_ms` (EMG onset relative to stretch onset),
`onset_method`.

## See also

[`tardieuScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuScore.md),
[`reflexThreshold()`](https://x-biosignal.github.io/PhysioMoCap/reference/reflexThreshold.md)

## Examples

``` r
fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
angle <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
tardieuStretch(angle, sampling_rate = fs, onset = "velocity")$catch_angle
#> [1] 25.07143
```
