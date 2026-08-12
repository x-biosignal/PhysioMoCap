# Angle between two 3D vectors

Computes the angle between pairs of 3D vectors. Accepts either single
vectors (length-3 numeric) or matrices where each row is a vector (n x
3). Vectorized for efficient computation across time frames.

## Usage

``` r
vectorAngle(v1, v2, degrees = TRUE)
```

## Arguments

- v1:

  Numeric vector of length 3 or matrix with 3 columns.

- v2:

  Numeric vector of length 3 or matrix with 3 columns.

- degrees:

  Logical. If `TRUE` (default), return angles in degrees. If `FALSE`,
  return in radians.

## Value

Numeric vector of angles. Length 1 for vector inputs, or `nrow(v1)` for
matrix inputs.

## Details

The angle is computed as: \$\$\theta = \arccos\left(\frac{v_1 \cdot
v_2}{\|v_1\| \|v_2\|}\right)\$\$

The dot product is clamped to \\\[-1, 1\]\\ before applying `acos` to
avoid numerical issues. If either vector has zero magnitude, the result
is `NA`.

The result is unsigned, in \\\[0, 180\]\\: it says how far apart the two
vectors are but not which side of `v1` that `v2` lies on, so
mirror-image configurations (joint flexion versus hyperextension) are
indistinguishable. For the signed variant, measured about a plane normal
and therefore able to separate the two, use
`calculateJointAngles(..., signed = TRUE)`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions: application to the knee."
Journal of Biomechanical Engineering, 105(2), 136-144.

## See also

[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md),
[`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md),
[`eulerToQuaternion()`](https://x-biosignal.github.io/PhysioMoCap/reference/eulerToQuaternion.md)

## Examples

``` r
# 90-degree angle
vectorAngle(c(1, 0, 0), c(0, 1, 0))
#> [1] 90

# Vectorized across rows
v1 <- matrix(c(1,0,0, 0,1,0), nrow = 2, byrow = TRUE)
v2 <- matrix(c(0,1,0, 0,0,1), nrow = 2, byrow = TRUE)
vectorAngle(v1, v2)
#> [1] 90 90
```
