# Detect foot-IMU stance phases for zero-velocity updates

Flags the stationary (foot-flat) samples of a foot-mounted IMU trace,
used as zero-velocity-update (ZUPT) anchors by
[`strapdownIntegrate()`](https://x-biosignal.github.io/PhysioMoCap/reference/strapdownIntegrate.md)
and
[`footImuGait()`](https://x-biosignal.github.io/PhysioMoCap/reference/footImuGait.md).
The default `"magnitude"` detector marks a sample as stance when the
accelerometer magnitude is close to gravity *and* the gyroscope
magnitude is small; the `"shoe"` detector is the SHOE (Stance Hypothesis
Optimal Estimation) generalised-likelihood-ratio test of Skog et al.
(2010).

## Usage

``` r
detectStanceZUPT(
  accel,
  gyro,
  sampling_rate,
  g = 9.81,
  method = c("magnitude", "shoe"),
  accel_threshold = 0.6,
  gyro_threshold = 0.6,
  sigma_a = 0.05,
  sigma_g = 0.05,
  gamma = 10000,
  window = NULL,
  min_stance = NULL
)
```

## Arguments

- accel:

  Numeric matrix (n x 3) of accelerometer readings (m/s^2).

- gyro:

  Numeric matrix (n x 3) of gyroscope readings (rad/s).

- sampling_rate:

  Sampling rate in Hz.

- g:

  Gravitational acceleration magnitude (default 9.81 m/s^2).

- method:

  `"magnitude"` (default) or `"shoe"`.

- accel_threshold:

  Magnitude method: max `|‖accel‖ - g|` for stance (default 0.6 m/s^2).

- gyro_threshold:

  Magnitude method: max `‖gyro‖` for stance (default 0.6 rad/s).

- sigma_a, sigma_g:

  SHOE method: accelerometer / gyroscope noise standard deviations
  (default 0.05 and 0.05).

- gamma:

  SHOE method: test-statistic threshold below which a sample is stance
  (default 1e4).

- window:

  Number of samples in the SHOE sliding window (default is about 50 ms
  of data).

- min_stance:

  Minimum stance-run length in samples; shorter runs are discarded as
  spurious (default is about 50 ms of data).

## Value

A logical vector of length `n`, `TRUE` at stance samples.

## References

Skog I, Handel P, Nilsson J-O, Rantakokko J (2010). "Zero-velocity
detection – an algorithm evaluation." IEEE Trans Biomed Eng
57(11):2657-2666.

## See also

[`strapdownIntegrate()`](https://x-biosignal.github.io/PhysioMoCap/reference/strapdownIntegrate.md),
[`footImuGait()`](https://x-biosignal.github.io/PhysioMoCap/reference/footImuGait.md).
