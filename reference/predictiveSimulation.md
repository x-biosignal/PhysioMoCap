# Predictive simulation: minimal-effort optimal control

Predicts the movement a limb model would produce to go from one posture
to another while minimising control effort (integral of squared joint
torque) – a direct-collocation optimal-control problem. Each joint
trajectory is a boundary-satisfying quintic plus interior basis
functions whose amplitudes are optimised; the required torque at each
node is obtained by inverse dynamics.

## Usage

``` r
predictiveSimulation(
  model,
  q0,
  qT,
  duration,
  n_nodes = 60L,
  n_basis = 3L,
  maxit = 200L
)
```

## Arguments

- model:

  A `planar_limb_model`.

- q0, qT:

  Start and target joint configurations (length `ndof`); velocity is
  zero at both ends.

- duration:

  Movement time (s).

- n_nodes:

  Collocation nodes for the effort integral (default 60).

- n_basis:

  Interior basis functions per joint (default 3).

- maxit:

  Optimiser iterations (default 200).

## Value

a `predictive_sim`: `time`, `q`, `qd`, `qdd`, `tau` (node x ndof),
`effort` (optimised) and `effort_baseline` (the minimum-jerk quintic),
the effort reduction, and boundary error.

## References

Todorov & Jordan (2002); Ackermann & van den Bogert (2010) predictive
simulation.

## See also

[`forwardDynamics()`](https://x-biosignal.github.io/PhysioMoCap/reference/forwardDynamics.md)

## Examples

``` r
m <- planarLimbModel(c(2.1, 1.4), c(0.3, 0.25), g = 0)   # horizontal reach
ps <- predictiveSimulation(m, q0 = c(0.2, 0.3), qT = c(1.1, 0.6),
                           duration = 0.6, n_basis = 2, maxit = 80)
ps$effort <= ps$effort_baseline                          # optimisation helps
#> [1] TRUE
```
