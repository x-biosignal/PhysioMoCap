# Generate a trajectory from a Dynamic Movement Primitive

Integrates a fitted
[`dmpFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpFit.md)
DMP, optionally generalising to a new goal, start or duration (temporal
scaling) while preserving the movement's shape and guaranteeing
convergence to the goal.

## Usage

``` r
dmpGenerate(dmp, goal = NULL, start = NULL, tau = NULL, n = 100L)
```

## Arguments

- dmp:

  A `dmp` from
  [`dmpFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpFit.md).

- goal, start:

  Optional new goal / start (length `D`); default the learned ones.

- tau:

  Optional new duration (temporal scaling); default the learned
  duration.

- n:

  Number of output samples (default 100).

## Value

a `dmp_trajectory`: `time`, `y`, `yd` (`n x D`).

## See also

[`dmpFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpFit.md)

## Examples

``` r
t <- seq(0, 1, length.out = 100)
y <- 10 * (10 * t^3 - 15 * t^4 + 6 * t^5)   # minimum-jerk demo
d <- dmpFit(y)
rollout <- dmpGenerate(d)
dim(rollout$y)
#> [1] 100   1
```
