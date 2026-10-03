# Signed Grood-Suntay / ISB joint angles from segment frames

Computes the three signed clinical joint angles - flexion/extension,
ab/adduction and internal/external rotation - from a proximal and a
distal anatomical segment frame, following the Grood-Suntay joint
coordinate system (the basis of the ISB recommendations). The flexion
axis is the proximal medio-lateral (Z) axis, the rotation axis is the
distal long (Y) axis, and the ab/adduction axis is the floating axis
perpendicular to both. This is equivalent to a Z-X-Y Cardan
decomposition of the relative rotation \\R = R_p^\top R_d\\; because it
is sequence-dependent, the flexion angle is extracted first and the
rotation last.

## Usage

``` r
groodSuntayAngles(proximal, distal, degrees = TRUE)
```

## Arguments

- proximal, distal:

  `n x 3 x 3` arrays of per-frame segment axes (columns X =
  antero-posterior, Y = long, Z = medio-lateral), as returned by
  [`jointCoordinateSystem`](https://x-biosignal.github.io/PhysioMoCap/reference/jointCoordinateSystem.md).

- degrees:

  Logical; return degrees (default) or radians.

## Value

A numeric `n x 3` matrix with columns `flexion`, `abduction` and
`rotation`.

## References

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions: application to the knee." J
Biomech Eng, 105(2), 136-144.

## See also

[`jointCoordinateSystem()`](https://x-biosignal.github.io/PhysioMoCap/reference/jointCoordinateSystem.md),
[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md)

## Examples

``` r
set.seed(1)
proximal <- array(rnorm(100 * 3 * 3), c(100, 3, 3))
distal <- array(rnorm(100 * 3 * 3), c(100, 3, 3))
ang <- groodSuntayAngles(proximal, distal)
head(ang)
#>         flexion abduction   rotation
#> [1,] -122.94297       -90  166.75640
#> [2,]  -58.96001        90  -99.52818
#> [3,] -144.25289       -90 -136.05456
#> [4,]   68.92221       -90  131.73075
#> [5,]  -97.65342       -90   19.67545
#> [6,]   93.71014       -90 -105.75731
```
