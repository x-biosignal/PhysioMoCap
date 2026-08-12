# Remove gravity from accelerometer data

Subtracts the rotated gravity vector from raw accelerometer data,
leaving only dynamic (linear) acceleration. The gravity direction is
determined by rotating the reference gravity vector `(0, 0, -g)` from
the world frame into the sensor frame using the provided orientation
quaternions.

## Usage

``` r
removeGravity(accel, orientation, g = 9.81)
```

## Arguments

- accel:

  Numeric matrix (n x 3) of raw accelerometer readings in m/s^2.

- orientation:

  A data.frame or matrix containing orientation quaternions. If a
  data.frame, must contain columns `q_w`, `q_x`, `q_y`, `q_z` (as
  returned by
  [`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md)).
  If a matrix, must have 4 columns (w, x, y, z).

- g:

  Numeric. Gravitational acceleration magnitude (default 9.81 m/s^2).

## Value

Numeric matrix (n x 3) of dynamic (gravity-free) acceleration.

## Details

For each time step, the gravity vector in the world frame `(0, 0, -g)`
is rotated into the sensor frame using the conjugate of the orientation
quaternion. This rotated gravity is then subtracted from the raw
accelerometer reading.

## References

Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
and MARG orientation using a gradient descent algorithm." IEEE
International Conference on Rehabilitation Robotics.

## See also

[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md),
[`calibrateIMU()`](https://x-biosignal.github.io/PhysioMoCap/reference/calibrateIMU.md),
[`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md)

## Examples

``` r
n <- 100
accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
gyro <- matrix(0, nrow = n, ncol = 3)
ori <- estimateOrientation(accel, gyro, sampling_rate = 100)
dyn_accel <- removeGravity(accel, ori)
```
