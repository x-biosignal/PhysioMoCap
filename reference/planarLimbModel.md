# Planar two-segment limb model (equations of motion)

Builds the analytic dynamics of a planar two-link limb with distributed
segment mass: the mass matrix `M(q)`, the Coriolis/centrifugal matrix,
the gravity vector, and forward/inverse dynamics. Angles are joint
angles (proximal, then distal relative to the proximal segment),
measured so gravity acts in `-y`.

## Usage

``` r
planarLimbModel(
  mass,
  length,
  com = length/2,
  inertia = mass * length^2/12,
  g = 9.81
)
```

## Arguments

- mass:

  Length-2 segment masses (kg).

- length:

  Length-2 segment lengths (m).

- com:

  Length-2 distances of each segment centre of mass from its proximal
  joint (m); default `length / 2`.

- inertia:

  Length-2 segment moments of inertia about the CoM (kg m^2); default
  the thin-rod `mass * length^2 / 12`.

- g:

  Gravitational acceleration (m/s^2, default 9.81; use 0 for a
  horizontal-plane / no-gravity model).

## Value

a `planar_limb_model`: functions `M(q)`, `coriolis(q, qd)` (matrix),
`gravity(q)`, `forward_accel(q, qd, tau)`,
`inverse_dynamics(q, qd, qdd)`, `energy(q, qd)` (kinetic, potential,
total), and `ndof = 2`.

## References

Spong MW, et al. (2006) Robot Modeling and Control.

## See also

[`forwardDynamics()`](https://x-biosignal.github.io/PhysioMoCap/reference/forwardDynamics.md),
[`predictiveSimulation()`](https://x-biosignal.github.io/PhysioMoCap/reference/predictiveSimulation.md)

## Examples

``` r
m <- planarLimbModel(mass = c(7, 3), length = c(0.4, 0.4))
m$energy(c(0, 0), c(1, 0))$total
#> [1] 0.7466667
```
