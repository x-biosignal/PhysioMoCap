# Time to peak torque

Time to peak torque

## Usage

``` r
timeToPeakTorque(
  torque,
  sampling_rate,
  onset = NULL,
  onset_method = c("absolute", "sd"),
  onset_threshold = 7.5,
  baseline_ms = 100,
  baseline_sd_k = 5
)
```

## Arguments

- torque:

  Numeric torque trace in N m.

- sampling_rate:

  Sampling rate in Hz.

- onset:

  Optional 1-based integer onset sample. When `NULL`, onset is detected
  from the baseline.

- onset_method:

  Either a fixed `"absolute"` increase above baseline or a baseline
  `"sd"` rule.

- onset_threshold:

  Absolute onset threshold in N m above baseline.

- baseline_ms:

  Baseline duration in milliseconds.

- baseline_sd_k:

  Number of baseline SDs used by the `"sd"` method.

## Value

A named list containing time from onset, time from trace start, peak and
onset indices, and peak torque.

## Examples

``` r
torque <- c(rep(0, 100), seq(0.4, 120, by = 0.4), rep(120, 100))
timeToPeakTorque(torque, sampling_rate = 1000, onset_method = "sd")
#> $time_from_onset
#> [1] 0.299
#> 
#> $time_from_start
#> [1] 0.399
#> 
#> $peak_index
#> [1] 400
#> 
#> $onset_index
#> [1] 101
#> 
#> $peak
#> [1] 120
#> 
```
