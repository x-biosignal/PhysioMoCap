# Velocity-dependent reflex threshold

Regresses the catch angle against the peak stretch velocity across a
series of passive stretches at varying velocities. A negative slope is
the signature of velocity-dependent spasticity (the catch occurs
earlier - at a smaller angle - as the stretch gets faster).

## Usage

``` r
reflexThreshold(stretches)
```

## Arguments

- stretches:

  A list of
  [`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md)
  results (\>= 2), one per stretch.

## Value

An S3 `reflex_threshold` list: `slope` (deg per deg/s), `intercept`,
`catch_angles`, `peak_velocities` and the linear `model`.

## See also

[`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md),
[`tardieuScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuScore.md)

## Examples

``` r
fs <- 200
mk <- function(catch, rise, total = 0.8) {
  t <- seq(0, total, by = 1 / fs)
  ifelse(t <= rise, catch * t / rise, catch + 8 * (t - rise) / (total - rise))
}
st <- lapply(list(c(30, .5), c(20, .25), c(15, .13)),
             function(p) tardieuStretch(mk(p[1], p[2]), sampling_rate = fs,
                                        onset = "velocity"))
reflexThreshold(st)$slope
#> [1] -0.2571113
```
