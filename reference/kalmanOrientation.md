# Kalman orientation filter (tilt + gyro-bias)

Fuses gyroscope and accelerometer with a per-axis linear Kalman filter
that estimates both the tilt angle and the (slowly varying) gyroscope
bias – the classic optimal complementary filter. Roll and pitch are
corrected by gravity; yaw is integrated (or corrected by a magnetometer
heading if supplied).

## Usage

``` r
kalmanOrientation(
  gyro,
  accel,
  sampling_rate,
  mag = NULL,
  q_angle = 0.001,
  q_bias = 0.003,
  r_measure = 0.03
)
```

## Arguments

- gyro:

  `n x 3` angular velocity (rad/s).

- accel:

  `n x 3` accelerometer.

- sampling_rate:

  Sampling rate (Hz).

- mag:

  Optional `n x 3` magnetometer for yaw.

- q_angle, q_bias:

  Process-noise variances for angle and bias (defaults 1e-3, 3e-3).

- r_measure:

  Measurement-noise variance of the accelerometer angle (default 0.03).

## Value

a data frame `time, roll, pitch, yaw` (rad) and quaternion columns, plus
attribute `bias` (estimated gyro bias per axis).

## References

Lauszus K (2012) Kalman IMU; Brown & Hwang (1997).

## See also

[`mahonyAHRS()`](https://x-biosignal.github.io/PhysioMoCap/reference/mahonyAHRS.md),
[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md)

## Examples

``` r
n <- 300; sr <- 100; t <- seq_len(n) / sr
roll <- 0.4 * sin(2 * pi * 0.4 * t); pitch <- 0.3 * sin(2 * pi * 0.25 * t)
accel <- cbind(-sin(pitch), sin(roll) * cos(pitch), cos(roll) * cos(pitch))
gyro <- cbind(c(0, diff(roll)) * sr + 0.05, c(0, diff(pitch)) * sr - 0.03, 0)
est <- kalmanOrientation(gyro, accel, sampling_rate = sr)
max(abs(est$roll - roll))
#> [1] 23.67232
```
