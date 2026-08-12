# Pure-R static optimization of muscle activations

Distributes the net joint moment at each time frame across muscles by
minimising the sum of squared activations (a quadratic muscle-effort
criterion), subject to the moments being reproduced exactly and each
activation staying within its bounds: \$\$\min_a \sum_i w_i a_i^2 \quad
\text{s.t.} \quad \tau_j = \sum_i a_i F^{max}\_i r\_{ji}, \\ 0 \le a_i
\le 1.\$\$ Each frame is an independent convex quadratic program (solved
with quadprog), giving the unique minimum-effort activations. This
mirrors the OpenSim Static Optimization tool (Anderson & Pandy 2001) and
is used by
[`runStaticOptimization()`](https://x-biosignal.github.io/PhysioMoCap/reference/runStaticOptimization.md)
when OpenSim is unavailable.

## Usage

``` r
staticOptimizationR(
  moment_arms,
  max_force,
  joint_moments,
  activation_bounds = c(0, 1),
  weights = NULL,
  passive_moments = NULL
)
```

## Arguments

- moment_arms:

  Muscle moment arms: either a single `n_dof x n_muscle` matrix `r`
  (moment arm of muscle *i* about degree-of-freedom *j*, reused for
  every frame) or a list of such matrices, one per frame.

- max_force:

  Numeric vector of muscle maximum isometric forces (`F_max`, length
  `n_muscle`).

- joint_moments:

  Net joint moments to reproduce: a length-`n_dof` vector (single frame)
  or an `n_frames x n_dof` matrix (one row per frame).

- activation_bounds:

  Length-2 numeric `c(lower, upper)` activation bounds (default
  `c(0, 1)`).

- weights:

  Optional length-`n_muscle` positive weights `w_i` for the effort
  criterion (default all 1).

- passive_moments:

  Optional passive/gravity joint moments subtracted from `joint_moments`
  before optimization (same shape as `joint_moments`).

## Value

A `static_optimization_r` object: a list with `activations`
(`n_frames x n_muscle`), `moments` (the reproduced net joint moments,
`n_frames x n_dof`), `residual` (max absolute moment error per frame),
`effort` (sum of squared activations per frame), `feasible` (logical per
frame), and the muscle / DOF counts.

## References

Anderson FC, Pandy MG (2001). "Static and dynamic optimization solutions
for gait are practically equivalent." J Biomech 34(2):153-161.

## See also

[`runStaticOptimization()`](https://x-biosignal.github.io/PhysioMoCap/reference/runStaticOptimization.md)

## Examples

``` r
if (requireNamespace("quadprog", quietly = TRUE)) {
  # Two muscles with unit moment arm and F_max reproduce a moment of 30.
  r <- matrix(c(1, 1), nrow = 1)
  so <- staticOptimizationR(r, max_force = c(100, 100), joint_moments = 30)
  so$activations
}
#>      [,1] [,2]
#> [1,] 0.15 0.15
```
