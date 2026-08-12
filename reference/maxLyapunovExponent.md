# Largest Lyapunov exponent (Rosenstein)

Estimates the largest Lyapunov exponent from the average logarithmic
divergence of initially nearby trajectories in a delay-embedded phase
space (Rosenstein et al. 1993). A positive exponent indicates sensitive
dependence on initial conditions (chaos / local instability).

## Usage

``` r
maxLyapunovExponent(
  x,
  delay = NULL,
  dim = NULL,
  sampling_rate = 1,
  mean_period = NULL,
  max_steps = NULL,
  fit_range = NULL
)
```

## Arguments

- x:

  Numeric time series.

- delay, dim:

  Embedding delay and dimension; `NULL` estimates them via
  [`timeDelayEmbed()`](https://x-biosignal.github.io/PhysioMoCap/reference/timeDelayEmbed.md).

- sampling_rate:

  Sampling rate in Hz (scales the exponent to per-second).

- mean_period:

  Theiler window in samples excluding temporally-close neighbours;
  `NULL` estimates it from the mean signal period.

- max_steps:

  Number of forward steps to track divergence; `NULL` uses a default
  derived from the series length.

- fit_range:

  Integer vector `c(from, to)` (in steps) of the divergence curve to fit
  the slope; `NULL` uses an early near-linear window.

## Value

A `lyapunov_exponent` object with `lambda` (per second), the
`divergence` curve, `fit_range`, `delay` and `dim`.

## References

Rosenstein MT, Collins JJ, De Luca CJ (1993). Physica D 65:117-134.

## See also

[`localDynamicStability()`](https://x-biosignal.github.io/PhysioMoCap/reference/localDynamicStability.md),
[`timeDelayEmbed()`](https://x-biosignal.github.io/PhysioMoCap/reference/timeDelayEmbed.md)
