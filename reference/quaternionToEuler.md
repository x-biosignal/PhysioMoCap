# Convert quaternion to Euler angles

Converts a quaternion (w, x, y, z) representation to Euler angles (roll,
pitch, yaw) using the specified rotation order.

## Usage

``` r
quaternionToEuler(w, x, y, z, order = "ZYX", degrees = TRUE)
```

## Arguments

- w:

  Numeric. Scalar (real) part of the quaternion.

- x:

  Numeric. First imaginary component.

- y:

  Numeric. Second imaginary component.

- z:

  Numeric. Third imaginary component.

- order:

  Character. Rotation order. Default `"ZYX"`.

- degrees:

  Logical. If `TRUE` (default), return Euler angles in degrees. If
  `FALSE`, return in radians.

## Value

A matrix with columns `roll`, `pitch`, `yaw`. If inputs are scalars,
returns a 1-row matrix. If inputs are vectors, returns a matrix with one
row per element.

## Details

For the `"ZYX"` (Tait-Bryan) convention:

- roll = rotation about X axis

- pitch = rotation about Y axis

- yaw = rotation about Z axis

The quaternion is assumed to be unit (normalized). If not unit, it is
normalized internally before conversion.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions: application to the knee."
Journal of Biomechanical Engineering, 105(2), 136-144.

## See also

[`eulerToQuaternion()`](https://x-biosignal.github.io/PhysioMoCap/reference/eulerToQuaternion.md),
[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md),
[`vectorAngle()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorAngle.md)

## Examples

``` r
# Identity quaternion -> zero Euler angles
quaternionToEuler(1, 0, 0, 0)
#>      roll pitch yaw
#> [1,]    0     0   0

# 90-degree rotation about Z axis
quaternionToEuler(cos(pi/4), 0, 0, sin(pi/4))
#>      roll pitch yaw
#> [1,]    0     0  90
```
