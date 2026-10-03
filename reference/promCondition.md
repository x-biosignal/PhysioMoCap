# Condition a ProMP on a via-point

Gaussian conditioning of a fitted
[`promFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/promFit.md)
ProMP so the trajectory distribution passes through a desired point at a
given phase, updating the mean and the variability band.

## Usage

``` r
promCondition(promp, phase, value, obs_sd = 0.001)
```

## Arguments

- promp:

  A `promp` from
  [`promFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/promFit.md).

- phase:

  Phase in \[0, 1\] of the via-point.

- value:

  Desired trajectory value at `phase`.

- obs_sd:

  Observation noise SD (smaller = tighter conditioning; default 1e-3).

## Value

an updated `promp` with the conditioned `mean`, `sd`, `w_mean`, `w_cov`.

## See also

[`promFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/promFit.md)

## Examples

``` r
z <- seq(0, 1, length.out = 50)
demos <- lapply(1:20, function(i) sin(2 * pi * z) + rnorm(50, 0, 0.1))
p <- promFit(demos)
cond <- promCondition(p, phase = 0.5, value = 1.0)
length(cond$mean)
#> [1] 50
```
