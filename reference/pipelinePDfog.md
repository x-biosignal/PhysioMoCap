# Parkinson's freezing-of-gait pipeline (freeze index)

Detects freezing of gait (FOG) from a windowed spectral freeze index:
the ratio of power in the freeze band (default 3-8 Hz) to power in the
locomotor band (default 0.5-3 Hz) of an accelerometer signal (Moore et
al. 2008; Bachlin et al. 2010). A window is flagged as FOG when the
freeze index exceeds `fi_threshold` and the band power exceeds
`power_threshold` (excluding rest).

## Usage

``` r
pipelinePDfog(
  accel,
  sampling_rate,
  window_sec = 4,
  step_sec = 0.5,
  freeze_band = c(3, 8),
  locomotor_band = c(0.5, 3),
  fi_threshold = 2,
  power_threshold = NULL
)
```

## Arguments

- accel:

  Accelerometer signal (e.g. shank/trunk vertical or resultant).

- sampling_rate:

  Sampling rate in Hz.

- window_sec, step_sec:

  Sliding-window length and step (seconds).

- freeze_band, locomotor_band:

  Frequency bands (Hz).

- fi_threshold:

  Freeze-index threshold for FOG (default 2).

- power_threshold:

  Minimum band power for a window to be considered (excludes rest).
  `NULL` uses the 10th percentile of windowed band power as a
  quiet-baseline floor (robust to a loud walking bout, unlike a
  maximum-relative gate); pass a fixed absolute value if the sensor
  units are known.

## Value

A `pd_fog_report` object with a per-window `windows` data frame (`time`,
`freeze_index`, `power`, `fog`) and the overall `fog_fraction`.

## References

Moore ST, et al. (2008); Bachlin M, et al. (2010).
