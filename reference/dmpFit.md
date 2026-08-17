# Fit a Dynamic Movement Primitive to a demonstration

Learns the forcing term of a DMP from one demonstrated trajectory, so it
can later be regenerated (and generalised to a new goal or duration) by
[`dmpGenerate()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpGenerate.md).

## Usage

``` r
dmpFit(y, times = NULL, n_basis = 25L, alpha_z = 25)
```

## Arguments

- y:

  Demonstration: a numeric vector (1-D) or `T x D` matrix (per-column
  DOF).

- times:

  Optional time stamps (length `T`); defaults to `0..1`.

- n_basis:

  Number of Gaussian basis functions (default 25).

- alpha_z:

  Attractor gain (default 25; damping `beta_z = alpha_z / 4`, critically
  damped).

## Value

a `dmp` object: learned weights (`n_basis x D`), goal, start, duration,
and parameters.

## References

Ijspeert AJ, et al. (2013) Neural Comput 25:328-373.

## See also

[`dmpGenerate()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpGenerate.md),
[`promFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/promFit.md)

## Examples

``` r
t <- seq(0, 1, length.out = 100)
y <- 10 * (10*t^3 - 15*t^4 + 6*t^5)               # min-jerk demo
d <- dmpFit(y); rg <- dmpGenerate(d)
max(abs(rg$y[, 1] - y))                            # reproduces the demo
#> [1] 0.2561058
```
