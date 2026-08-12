# Calibrate IMU from static data

Estimates accelerometer and gyroscope biases from data recorded during a
static (motionless) period. The accelerometer bias is computed relative
to the expected gravity vector, and the gyroscope bias is the mean
angular velocity during the static period.

## Usage

``` r
calibrateIMU(accel_static, gyro_static)
```

## Arguments

- accel_static:

  Numeric matrix (n x 3) of accelerometer readings during the static
  period, in m/s^2.

- gyro_static:

  Numeric matrix (n x 3) of gyroscope readings during the static period,
  in rad/s.

## Value

A list with components:

- accel_bias:

  Numeric vector of length 3. Mean accelerometer bias for each axis. For
  a perfectly calibrated sensor at rest, this would be (0, 0, 0) after
  accounting for gravity.

- gyro_bias:

  Numeric vector of length 3. Mean gyroscope bias for each axis (rad/s).
  A stationary sensor should read zero; any offset is the bias.

## Details

The function assumes the sensor is stationary. The accelerometer bias is
estimated by subtracting the expected gravity contribution from the mean
accelerometer reading. Gravity direction is inferred from the mean
acceleration direction, and its expected magnitude is 9.81 m/s^2.

The gyroscope bias is simply the mean of the gyroscope readings during
the static period (should be near zero for a stationary sensor).

## References

Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
and MARG orientation using a gradient descent algorithm." IEEE
International Conference on Rehabilitation Robotics.

## See also

[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md),
[`removeGravity()`](https://x-biosignal.github.io/PhysioMoCap/reference/removeGravity.md)

## Examples

``` r
# Simulate static IMU data with known biases
n <- 500
accel_bias_true <- c(0.05, -0.03, 0.02)
gyro_bias_true <- c(0.001, -0.002, 0.0015)
accel <- matrix(rep(c(0, 0, -9.81), each = n), ncol = 3) +
  matrix(rep(accel_bias_true, each = n), ncol = 3)
gyro <- matrix(rep(gyro_bias_true, each = n), ncol = 3)
cal <- calibrateIMU(accel, gyro)
```
