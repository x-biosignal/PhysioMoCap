# Instrumented Timed Up-and-Go (iTUG)

Segments a Timed Up-and-Go trial from a trunk/lumbar inertial sensor
into its sub-phases (sit-to-stand, walk, turn, turn-to-sit) using the
angular velocity: turns appear as large excursions of the vertical-axis
(yaw) angular velocity, and the postural sit-to-stand / turn-to-sit
transitions as the trunk flexion-axis (pitch) events that bracket the
walking (Salarian et al. 2010).

## Usage

``` r
instrumentedTUG(
  angular_velocity,
  sampling_rate,
  turn_axis = 3L,
  transition_axis = 2L,
  turn_threshold = NULL,
  min_turn_sec = 0.3
)
```

## Arguments

- angular_velocity:

  An n x 3 matrix of trunk angular velocity (rad/s).

- sampling_rate:

  Sampling rate in Hz.

- turn_axis:

  Column index of the vertical/yaw axis (default 3).

- transition_axis:

  Column index of the trunk flexion/pitch axis (default 2).

- turn_threshold:

  Angular-velocity threshold (rad/s) that marks a turn; `NULL` uses
  `0.15 * max(abs(yaw))`.

- min_turn_sec:

  Minimum turn duration in seconds (default 0.3).

## Value

An `itug_report` object with `total_duration`, a `turns` data frame
(`start`, `end`, `duration`, `peak_velocity`, `angle_deg`), the
`stand_up_time`/`sit_down_time`, and a `phases` data frame.

## References

Salarian A, et al. (2010). IEEE Trans Neural Syst Rehabil Eng
18(3):303-310.

## See also

[`instrumented10mWT()`](https://x-biosignal.github.io/PhysioMoCap/reference/instrumented10mWT.md)
