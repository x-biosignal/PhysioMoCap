# Local dynamic stability (short- and long-term divergence)

Local dynamic stability quantifies how a system responds to small
natural perturbations, as the exponential divergence rate of
neighbouring trajectories over the short term (0-1 stride,
`lambda_short`) and long term (4-10 strides, `lambda_long`), following
Dingwell & Cusumano (2000). Higher divergence means less stable
locomotion.

## Usage

``` r
localDynamicStability(
  x,
  stride_samples,
  delay = NULL,
  dim = NULL,
  sampling_rate = 1
)
```

## Arguments

- x:

  Numeric time series (e.g. trunk acceleration or a joint angle).

- stride_samples:

  Samples per stride (sets the divergence windows).

- delay, dim:

  Embedding parameters; `NULL` estimates them.

- sampling_rate:

  Sampling rate in Hz.

## Value

A `local_dynamic_stability` object with `lambda_short`, `lambda_long`
(per stride), the `divergence` curve, and embedding info.

## References

Dingwell JB, Cusumano JJ (2000). Chaos 10(4):848-863.

## See also

[`maxLyapunovExponent()`](https://x-biosignal.github.io/PhysioMoCap/reference/maxLyapunovExponent.md)
