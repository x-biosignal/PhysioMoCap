# Rate of force development

Computes sequential interval RFD from contraction onset and the maximum
moving-window slope. RFD is expressed in N m/s.

## Usage

``` r
rateOfForceDevelopment(
  torque,
  sampling_rate,
  onset = NULL,
  onset_method = c("absolute", "sd"),
  onset_threshold = 7.5,
  baseline_ms = 100,
  baseline_sd_k = 5,
  windows_ms = c(50, 100, 200),
  peak_window_ms = 20
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

- windows_ms:

  Positive interval widths in milliseconds.

- peak_window_ms:

  Positive moving-window width in milliseconds.

## Value

An `rfd` object containing onset details, interval RFD values, and peak
moving-window RFD.

## References

Aagaard P, Simonsen EB, Andersen JL, Magnusson P, Dyhre-Poulsen P
(2002). Increased rate of force development and neural drive of human
skeletal muscle following resistance training. *Journal of Applied
Physiology*, 93:1318-1326.
[doi:10.1152/japplphysiol.00283.2002](https://doi.org/10.1152/japplphysiol.00283.2002)

Maffiuletti NA, Aagaard P, Blazevich AJ, Folland J, Tillin N, Duchateau
J (2016). Rate of force development: physiological and methodological
considerations. *European Journal of Applied Physiology*, 116:1091-1116.
[doi:10.1007/s00421-016-3346-6](https://doi.org/10.1007/s00421-016-3346-6)

## Examples

``` r
torque <- c(rep(0, 100), seq(0.4, 120, by = 0.4), rep(120, 100))
rateOfForceDevelopment(torque, sampling_rate = 1000, onset_method = "sd")
#> <rfd> onset 0.100 s (sample 101)
#>   0-50 ms: 400.000 N m/s
#>   0-100 ms: 400.000 N m/s
#>   0-200 ms: 400.000 N m/s
#>   peak (20 ms): 400.000 N m/s
```
