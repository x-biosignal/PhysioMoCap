# Instrumented 10-metre walk test (10mWT)

Extracts steady-state gait speed (and cadence) over the middle section
of a 10-metre walk, excluding the acceleration and deceleration zones,
from the forward walking distance over time (e.g. the ZUPT-integrated
foot trajectory from
[`footImuGait()`](https://x-biosignal.github.io/PhysioMoCap/reference/footImuGait.md)
or a marker distance).

## Usage

``` r
instrumented10mWT(
  position,
  sampling_rate,
  total_distance = 10,
  mid_start = 2,
  mid_end = 8,
  events = NULL,
  events_unit = c("auto", "index", "seconds")
)
```

## Arguments

- position:

  Cumulative forward distance walked (m) over time.

- sampling_rate:

  Sampling rate in Hz.

- total_distance:

  Total walkway length in m (default 10).

- mid_start, mid_end:

  Start/end of the timed steady-state section in m (defaults 2 and 8).

- events:

  Optional heel-strike sample indices or times (s) for cadence.

- events_unit:

  Unit of `events`: `"auto"` (default) guesses indices vs seconds, or
  force `"index"` / `"seconds"`. Pass an explicit unit when heel-strike
  times are whole-number seconds (which `"auto"` would otherwise read as
  sample indices).

## Value

A `walk_test_report` object with `gait_speed` (m/s), `mid_distance`,
`mid_time`, `cadence_spm` (or `NA`), and the section boundary times.

## References

Standard 10-metre walk test protocol.

## See also

[`instrumentedTUG()`](https://x-biosignal.github.io/PhysioMoCap/reference/instrumentedTUG.md),
[`footImuGait()`](https://x-biosignal.github.io/PhysioMoCap/reference/footImuGait.md)
