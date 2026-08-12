# Calculate gait temporal-spatial parameters

Computes temporal and spatial gait parameters from detected gait events.
Temporal parameters include stride time, step time, stance/swing
durations, double support time, and cadence. Spatial parameters (step
length, stride length, step width, walking speed) require position data
in the PhysioExperiment assays.

## Usage

``` r
calculateGaitParameters(
  pe,
  events,
  body_height = NULL,
  side = c("right", "left", "both")
)
```

## Arguments

- pe:

  A PhysioExperiment object with position data (assays named
  `position_x`, `position_y`, or `position_z`).

- events:

  A `detected_events` object (from
  [`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md))
  or a data.frame with at minimum columns `event_name` (or `event`) and
  `time` (sample indices or seconds), plus `side` (`"right"` or
  `"left"`).

- body_height:

  Numeric; body height in metres for normalized parameters (optional).
  Currently reserved for future use.

- side:

  Character; which side(s) to compute. One of `"right"`, `"left"`, or
  `"both"` (default).

## Value

An S3 object of class `"gait_parameters"` inheriting from `data.frame`.
Each row is one stride cycle. Columns include:

- side:

  Side label (`"right"` or `"left"`)

- stride:

  Stride number (sequential within side)

- stride_time:

  Time between consecutive ipsilateral heel strikes (s)

- step_time:

  Time from contralateral to ipsilateral heel strike (s)

- stance_time:

  Heel strike to toe off on the same side (s)

- swing_time:

  Toe off to next heel strike on the same side (s)

- stance_percent:

  Stance as percentage of stride time

- swing_percent:

  Swing as percentage of stride time

- double_support_time:

  Time with both feet on the ground (s)

- cadence:

  Steps per minute (`60 / step_time`)

- step_length:

  AP distance between feet at consecutive heel strikes (m)

- stride_length:

  AP distance between ipsilateral heel strikes (m)

- step_width:

  ML distance between feet at heel strike (m)

- walking_speed:

  Stride length / stride time (m/s)

## Details

Events must use one of the recognised naming conventions:

- `"HS_R"`, `"HS_L"` / `"TO_R"`, `"TO_L"`

- `"right_heel_strike"`, `"left_heel_strike"` / `"right_toe_off"`,
  `"left_toe_off"`

The `events` data.frame may use either `event_name` or `event` for the
event name column, and either `time` (in sample indices) or `time_sec`
(in seconds) for timing.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

Perry J, Burnfield JM (2010). "Gait Analysis: Normal and Pathological
Function." 2nd ed. SLACK Incorporated.

## See also

[`calculateStepSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateStepSymmetry.md)
for symmetry analysis of gait parameters,
[`summarizeGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeGaitParameters.md)
for descriptive statistics of gait data,
[`plotGaitCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGaitCycle.md)
for gait cycle visualization.

## Examples

``` r
# See test file for worked examples with synthetic data
```
