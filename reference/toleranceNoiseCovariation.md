# Tolerance-Noise-Covariation (TNC) decomposition of result error

Decomposes the mean result error of a set of executions (Muller &
Sternad 2004): how much error is removable by moving the mean to a more
**tolerant** region, how much is due to dispersion (**noise**) around
that region, and how much the observed inter-variable **covariation**
already saves relative to a de-covaried (column-permuted) surrogate.

## Usage

``` r
toleranceNoiseCovariation(
  execution,
  error_fn,
  optimum = NULL,
  n_surrogate = 200L
)
```

## Arguments

- execution:

  An `N x m` matrix of execution variables.

- error_fn:

  A vectorised error function: given an `N x m` matrix it returns the
  length-`N` per-trial error (\>= 0, 0 = perfect).

- optimum:

  Length-`m` execution vector achieving (near-)zero error, used as the
  most tolerant target. When `NULL`, the dispersion (noise) reference is
  the cloud centroid.

- n_surrogate:

  Number of column-permutation surrogates for the covariation estimate
  (default 200).

## Value

a `tnc_result` list: `tolerance`, `noise`, `covariation` (error
components; covariation \> 0 = the observed covariation reduces error),
`e_data` (mean data error), `e_optimum`.

## References

Muller H, Sternad D (2004) J Exp Psychol Hum Percept Perform 30:212-233;
Cohen RG, Sternad D (2009) Exp Brain Res 193:69-83.

## See also

[`uncontrolledManifold()`](https://x-biosignal.github.io/PhysioMoCap/reference/uncontrolledManifold.md)

## Examples

``` r
set.seed(3)
# redundant reaching task: result = x1 + x2, target 20, error squared
x1 <- rnorm(300, 12, 3); x2 <- 20 - x1 + rnorm(300, 0, 0.6)   # covary to hit 20
err <- function(M) (M[, 1] + M[, 2] - 20)^2
toleranceNoiseCovariation(cbind(x1, x2), err, optimum = c(10, 10))$covariation
#> [1] 17.5002
```
