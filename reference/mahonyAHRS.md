# Mahony AHRS orientation filter

Estimates orientation by integrating the gyroscope while correcting
drift with the accelerometer (gravity) and optional magnetometer through
a proportional+integral complementary feedback on SO(3) (Mahony et al.
2008).

## Usage

``` r
mahonyAHRS(gyro, accel, sampling_rate, kp = 1, ki = 0.1)
```

## Arguments

- gyro:

  `n x 3` angular velocity (rad/s), columns x, y, z.

- accel:

  `n x 3` accelerometer (any consistent unit; normalised internally).

- sampling_rate:

  Sampling rate (Hz).

- kp, ki:

  Proportional and integral feedback gains (default 1, 0.1).

## Value

a data frame `time, roll, pitch, yaw` (rad) and `q_w, q_x, q_y, q_z`,
matching
[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md).

## References

Mahony R, et al. (2008) IEEE Trans Autom Control 53:1203-1218.

## See also

[`kalmanOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/kalmanOrientation.md),
[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md)

## Examples

``` r
n <- 200; sr <- 100; t <- seq_len(n) / sr
roll <- 0.3 * sin(2 * pi * 0.5 * t); pitch <- 0.2 * cos(2 * pi * 0.3 * t)
accel <- cbind(-sin(pitch), sin(roll) * cos(pitch), cos(roll) * cos(pitch))
gyro <- cbind(c(0, diff(roll)) * sr, c(0, diff(pitch)) * sr, 0)
est <- mahonyAHRS(gyro, accel, sampling_rate = sr)
max(abs(est$roll - roll))
#> [1] 17.30515
```
