# Uncontrolled Manifold (UCM) analysis of motor variability

Decomposes trial-to-trial variance of the elemental variables into the
part lying in the uncontrolled manifold (the null space of the task
Jacobian – variability that does not change the task variable, "good")
and the part orthogonal to it (variability that does, "bad"). A positive
synergy index means the elements co-vary to stabilise the task.

## Usage

``` r
uncontrolledManifold(theta, jacobian = NULL, task = NULL)
```

## Arguments

- theta:

  An `N x n` matrix: `N` trials (repetitions), `n` elemental variables
  (e.g. joint angles).

- jacobian:

  The `d x n` task Jacobian at the mean configuration (`d` = dimension
  of the task variable). Provide this, or `task`.

- task:

  Optional task function `R^n -> R^d`; its Jacobian is computed
  numerically at `colMeans(theta)` when `jacobian` is not given.

## Value

a `ucm_result` list: `v_ucm`, `v_ort` (variance per DOF, parallel and
orthogonal to the manifold), `v_total`, `delta_v` (synergy index,
`(v_ucm - v_ort) / v_total`; \> 0 = task-stabilising synergy), `n`, `d`,
`N`.

## References

Scholz JP, Schoner G (1999) Exp Brain Res 126:289-306; Latash ML, et al.
(2002) Exerc Sport Sci Rev 30:26-31.

## See also

[`goalEquivalentManifold()`](https://x-biosignal.github.io/PhysioMoCap/reference/goalEquivalentManifold.md),
[`toleranceNoiseCovariation()`](https://x-biosignal.github.io/PhysioMoCap/reference/toleranceNoiseCovariation.md)

## Examples

``` r
set.seed(1)
# redundant task: total = a1 + a2 held constant; variance mostly along the UCM
a1 <- rnorm(200, 30, 4); a2 <- 60 - a1 + rnorm(200, 0, 0.5)
uncontrolledManifold(cbind(a1, a2), jacobian = matrix(c(1, 1), nrow = 1))$delta_v
#> [1] 1.981731
```
