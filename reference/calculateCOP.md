# Calculate center of pressure (COP) from force-plate data

Computes COP coordinates from force and moment components using standard
force-plate equations (assuming a vertical Z axis).

## Usage

``` r
calculateCOP(forces, moments, origin = c(0, 0, 0), min_vertical_force = 20)
```

## Arguments

- forces:

  Matrix/data.frame with at least three columns for force components (X,
  Y, Z).

- moments:

  Matrix/data.frame with at least three columns for moment components
  (X, Y, Z).

- origin:

  Numeric length-3 vector with force-plate origin `(x, y, z)`.

- min_vertical_force:

  Minimum absolute vertical force required to compute COP (samples below
  this threshold are set to `NA`).

## Value

A data.frame with columns `cop_x`, `cop_y`, `cop_z`, `free_moment`, and
`vertical_force`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for comprehensive force plate analysis,
[`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md)
for whole-body center of mass computation.

## Examples

``` r
f <- cbind(Fx = rep(0, 10), Fy = rep(0, 10), Fz = rep(1000, 10))
m <- cbind(Mx = rep(100, 10), My = rep(-200, 10), Mz = rep(0, 10))
cop <- calculateCOP(f, m)
```
