# Forward dynamics: integrate the equations of motion

Given a limb model, initial state and joint torques, integrates the
motion with a fixed-step 4th-order Runge-Kutta scheme.

## Usage

``` r
forwardDynamics(model, q0, qd0, torque = NULL, dt = 0.001, n_steps = 1000L)
```

## Arguments

- model:

  A `planar_limb_model` (or any list with a `forward_accel(q, qd, tau)`
  and `ndof`).

- q0, qd0:

  Initial joint angles and velocities (length `ndof`).

- torque:

  Joint torques: `NULL` (free/passive), a length-`ndof` constant, an
  `n_steps x ndof` matrix, or a function `(t, q, qd) -> torque`.

- dt:

  Time step (s).

- n_steps:

  Number of integration steps.

## Value

an `fd_result`: `time`, `q`, `qd` (`(n_steps+1) x ndof`), `tau`, and
`energy` (total mechanical energy per step).

## See also

[`planarLimbModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/planarLimbModel.md),
[`predictiveSimulation()`](https://x-biosignal.github.io/PhysioMoCap/reference/predictiveSimulation.md)

## Examples

``` r
m <- planarLimbModel(c(7, 3), c(0.4, 0.4))
fd <- forwardDynamics(m, q0 = c(pi/2 - 0.3, 0.2), qd0 = c(0, 0),
                      torque = NULL, dt = 0.001, n_steps = 500)
diff(range(fd$energy)) / mean(abs(fd$energy))     # ~ 0: energy conserved
#> [1] 1.137417e-10
```
