# Fit a Probabilistic Movement Primitive to demonstrations

Learns a distribution over trajectories from several demonstrations:
each is projected onto a Gaussian basis, and the basis weights are
modelled as Gaussian, giving a mean trajectory and a variability band.

## Usage

``` r
promFit(demos, n_basis = 15L, ridge = 1e-06)
```

## Arguments

- demos:

  A list of demonstrations (each a numeric vector, all resampled to the
  same length), or an `N x T` matrix (one demo per row).

- n_basis:

  Number of Gaussian basis functions (default 15).

- ridge:

  Ridge penalty for the per-demo weight fit (default 1e-6).

## Value

a `promp` object: `mean` and `sd` trajectories, the weight mean `w_mean`
and covariance `w_cov`, the basis `Phi`, and phase `z`.

## References

Paraschos A, et al. (2013) NIPS 26.

## See also

[`promCondition()`](https://x-biosignal.github.io/PhysioMoCap/reference/promCondition.md),
[`dmpFit()`](https://x-biosignal.github.io/PhysioMoCap/reference/dmpFit.md)

## Examples

``` r
z <- seq(0, 1, length.out = 50)
demos <- lapply(1:20, function(i) sin(2 * pi * z) + rnorm(50, 0, 0.1))
p <- promFit(demos)
length(p$mean)                                     # mean trajectory
#> [1] 50
```
