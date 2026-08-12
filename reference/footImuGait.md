# Foot-IMU spatiotemporal gait parameters

End-to-end foot-mounted IMU gait pipeline: estimate orientation, remove
gravity, rotate acceleration into the world frame, detect stance, and
ZUPT-integrate to a drift-bounded foot trajectory, then derive
per-stride stride length, foot clearance, stance/swing time and gait
velocity.

## Usage

``` r
footImuGait(
  accel,
  gyro,
  sampling_rate,
  g = 9.81,
  orientation = NULL,
  orientation_method = c("madgwick", "complementary"),
  beta = 0.02,
  stance = NULL,
  vertical_axis = 3,
  ...
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

- orientation:

  Optional orientation (a data frame with `q_w`/`q_x`/`q_y`/ `q_z`, or
  an n x 4 quaternion matrix). If `NULL`,
  [`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md)
  is run internally.

- orientation_method:

  Sensor-fusion method for the internal orientation estimate,
  `"madgwick"` (default) or `"complementary"`. Ignored when
  `orientation` is supplied.

- beta:

  Madgwick filter gain for the internal orientation estimate (default
  0.02). A foot IMU sees large dynamic accelerations, so a small,
  gyro-dominant gain avoids swing-phase tilt error; raise it for
  lower-dynamic mounting or noisier gyroscopes. Ignored when
  `orientation` is supplied.

- stance:

  Optional logical stance vector; if `NULL`,
  [`detectStanceZUPT()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStanceZUPT.md)
  is used.

- vertical_axis:

  World axis that points up (1, 2 or 3; default 3). Used for foot
  clearance and to de-drift vertical position to the floor.

- ...:

  Additional arguments forwarded to
  [`detectStanceZUPT()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStanceZUPT.md)
  (e.g. `method`, `accel_threshold`).

## Value

An `imu_gait` object: a list with `strides` (a data frame with one row
per detected stride: `stride`, `stride_length`, `foot_clearance`,
`stance_time`, `swing_time`, `stride_time`, `gait_velocity`), the
world-frame `position` and `velocity` matrices, the `stance` mask, and
`sampling_rate`.

## References

Mariani B et al. (2010) J Biomech 43(15):2999-3006; Rebula JR, Ojeda LV,
Adamczyk PG, Kuo AD (2013). "Measurement of foot placement and its
variability with inertial sensors." Gait & Posture 38(4):974-980.

## See also

[`detectStanceZUPT()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStanceZUPT.md),
[`strapdownIntegrate()`](https://x-biosignal.github.io/PhysioMoCap/reference/strapdownIntegrate.md),
[`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md),
[`removeGravity()`](https://x-biosignal.github.io/PhysioMoCap/reference/removeGravity.md).
