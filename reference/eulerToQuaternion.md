# Convert Euler angles to quaternion

Converts Euler angles (roll, pitch, yaw) to quaternion (w, x, y, z)
representation using the specified rotation order.

## Usage

``` r
eulerToQuaternion(roll, pitch, yaw, order = "ZYX")
```

## Arguments

- roll:

  Numeric. Rotation about X axis (in radians by default, or degrees if
  values \> 2\*pi suggest degree input).

- pitch:

  Numeric. Rotation about Y axis.

- yaw:

  Numeric. Rotation about Z axis.

- order:

  Character. Rotation order. Default `"ZYX"`.

## Value

A matrix with columns `w`, `x`, `y`, `z`. If inputs are scalars, returns
a 1-row matrix. If inputs are vectors, returns a matrix with one row per
element.

## Details

Input angles are assumed to be in **radians**. For the `"ZYX"`
convention, the combined quaternion is computed as: \\q = q_z \otimes
q_y \otimes q_x\\

The resulting quaternion is always returned with \\w \geq 0\\ (canonical
form).

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions: application to the knee."
Journal of Biomechanical Engineering, 105(2), 136-144.

## See also

[`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md),
[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md),
[`vectorAngle()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorAngle.md)

## Examples

``` r
# Zero rotation -> identity quaternion
eulerToQuaternion(0, 0, 0)
#>      w x y z
#> [1,] 1 0 0 0

# 90-degree rotation about Z axis (input in radians)
eulerToQuaternion(0, 0, pi/2)
#>              w x y         z
#> [1,] 0.7071068 0 0 0.7071068
```
