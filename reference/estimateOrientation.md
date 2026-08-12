# Estimate orientation from IMU sensors using sensor fusion

Fuses accelerometer, gyroscope, and optionally magnetometer data to
estimate 3D orientation over time. Returns both quaternion and Euler
angle representations.

## Usage

``` r
estimateOrientation(
  accel,
  gyro,
  mag = NULL,
  method = c("madgwick", "complementary"),
  beta = 0.1,
  sampling_rate
)
```

## Arguments

- accel:

  Numeric matrix (n x 3) of accelerometer readings in m/s^2. Columns
  correspond to x, y, z axes.

- gyro:

  Numeric matrix (n x 3) of gyroscope readings in rad/s. Columns
  correspond to x, y, z axes.

- mag:

  Numeric matrix (n x 3) of magnetometer readings, or `NULL` if
  unavailable. Default `NULL`.

- method:

  Character. Sensor fusion method: `"madgwick"` (default) or
  `"complementary"`.

- beta:

  Numeric. Filter gain for the Madgwick filter (default 0.1). For the
  complementary filter this parameter sets the alpha coefficient
  (gyroscope trust weight). Lower values for Madgwick or higher values
  for complementary increase reliance on the gyroscope.

- sampling_rate:

  Numeric. Sampling rate in Hz.

## Value

A data.frame with columns:

- time:

  Time in seconds from start.

- roll:

  Roll angle (degrees), rotation about X axis.

- pitch:

  Pitch angle (degrees), rotation about Y axis.

- yaw:

  Yaw angle (degrees), rotation about Z axis.

- q_w:

  Quaternion scalar component.

- q_x:

  Quaternion x component.

- q_y:

  Quaternion y component.

- q_z:

  Quaternion z component.

## Details

The Madgwick filter uses a gradient-descent algorithm to correct
gyroscope drift using accelerometer (and optionally magnetometer)
measurements. The `beta` parameter controls the correction strength.

The complementary filter blends gyroscope integration (high-pass) with
accelerometer tilt estimation (low-pass). The `beta` parameter serves as
the alpha coefficient, controlling the balance between gyroscope and
accelerometer contributions.

## References

Madgwick SOH, Harrison AJL, Vaidyanathan R (2011). "Estimation of IMU
and MARG orientation using a gradient descent algorithm." IEEE
International Conference on Rehabilitation Robotics.

## See also

[`removeGravity()`](https://x-biosignal.github.io/PhysioMoCap/reference/removeGravity.md),
[`calibrateIMU()`](https://x-biosignal.github.io/PhysioMoCap/reference/calibrateIMU.md),
[`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md)

## Examples

``` r
# Simulate static IMU data (sensor resting with gravity along -Z)
n <- 100
accel <- matrix(c(rep(0, n), rep(0, n), rep(-9.81, n)), ncol = 3)
gyro <- matrix(0, nrow = n, ncol = 3)
result <- estimateOrientation(accel, gyro, sampling_rate = 100)
head(result)
#>   time roll pitch yaw q_w q_x q_y q_z
#> 1 0.00    0     0   0   1   0   0   0
#> 2 0.01    0     0   0   1   0   0   0
#> 3 0.02    0     0   0   1   0   0   0
#> 4 0.03    0     0   0   1   0   0   0
#> 5 0.04    0     0   0   1   0   0   0
#> 6 0.05    0     0   0   1   0   0   0
```
