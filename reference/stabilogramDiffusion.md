# Stabilogram diffusion analysis (Collins & De Luca 1993)

Computes the mean square displacement (MSD) of the CoP as a function of
the time interval and extracts the short-term and long-term diffusion
coefficients and the critical point (the crossover between open-loop and
closed-loop postural control). Planar (resultant) and per-axis analyses
are returned.

## Usage

``` r
stabilogramDiffusion(
  cop,
  sampling_rate,
  ap = NULL,
  ml = NULL,
  detrend = c("mean", "none"),
  max_interval = 10,
  short_max = 1,
  long_min = 2.5
)
```

## Arguments

- cop, ap, ml, sampling_rate, detrend:

  As in
  [`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md).

- max_interval:

  Maximum time interval in seconds over which to compute the MSD
  (default 10, capped at half the record length).

- short_max, long_min:

  Interval boundaries (seconds) for the short-term (default `<= 1 s`)
  and long-term (default `>= 2.5 s`) linear regions used to estimate the
  diffusion coefficients.

## Value

A `stabilogram_diffusion` object with, per component (`planar`, `ap`,
`ml`), the short/long diffusion coefficients, scaling exponents (Hurst)
and the critical-point interval and MSD.

## References

Collins JJ, De Luca CJ (1993). Exp Brain Res 95:308-318.

## See also

[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md)

## Examples

``` r
set.seed(1)
n <- 3000
cop <- data.frame(cop_x = cumsum(rnorm(n)) * 0.05,
                  cop_y = cumsum(rnorm(n)) * 0.05)
stabilogramDiffusion(cop, sampling_rate = 100)
#> <stabilogram_diffusion>
#>   planar Ds=0.1071 Dl=0.05532 Hs=0.467 Hl=0.367 crit=(2 s, 0.874)
#>   ap     Ds=0.1147 Dl=0.06055 Hs=0.474 Hl=0.335 crit=(2.64 s, 0.611)
#>   ml     Ds=0.09955 Dl=0.0501 Hs=0.459 Hl=0.412 crit=(1.31 s, 0.271)
```
