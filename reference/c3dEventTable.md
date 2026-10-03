# Extract C3D Parameter Events on the Recording Clock

Converts the `EVENT` parameter group retained by
[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)
into a table of seconds relative to the first stored point sample. The
event clock must be declared explicitly. Header events are not read by
this function.

## Usage

``` r
c3dEventTable(
  x,
  event_time_reference,
  first_frame = NULL,
  snap = c("none", "point"),
  tolerance = 1e-05,
  outside = c("error", "keep")
)
```

## Arguments

- x:

  A `PhysioExperiment` with `metadata(x)$c3d_parameters`.

- event_time_reference:

  Either `"trial"` (C3D frame 1 is time zero) or `"recording"` (first
  stored sample is time zero). Required; not inferred.

- first_frame:

  Optional positive, one-based original first point frame, for
  trial-referenced events. Otherwise read from
  `TRIAL:ACTUAL_START_FIELD`. An explicit value overrides the stored
  parameter and is reported in output.

- snap:

  `"none"` preserves continuous event times. `"point"` explicitly
  requests rounding to the nearest point-sample grid, for frame
  annotations.

- tolerance:

  Maximum absolute rounding residual in seconds when `snap="point"`.
  Must be nonnegative and less than half a point period.

- outside:

  `"error"` rejects events outside the stored point sample times;
  `"keep"` retains them with `in_recording=FALSE`.

## Value

A data frame in original event order with `event_index`, `label`,
`context`, `raw_minutes`, `raw_seconds`, `raw_time`, `time`,
`snap_residual_s`, `recording_origin`, `first_frame`,
`event_time_reference`, `snap`, and `in_recording`. `time` is relative
to the recording start; `raw_time` is the declared event clock. Residual
is raw minus snapped time on that clock, or zero when snapping is
disabled. No-event files return a typed empty table. No sorting, event
detection, or gait-cycle inference is performed. Event accuracy and the
declared clock remain caller concerns.

## Details

Point rate must match `samplingRate(x)`. A trial origin is never
silently replaced with zero. `ACTUAL_START_FIELD` comprises two unsigned
16-bit words, low word first; signed 16-bit storage is decoded as
unsigned. Snapping is opt-in because a continuous event need not lie on
a point frame. This adapter does not change the signals or their local
sample grid. Applying it after cropping requires updating the first
frame to match the stored samples.

Operates on a parsed C3D object from the optional `c3dr` package, built
from a binary `.c3d` file, so the example cannot run offline and is not
executed.

## References

C3D.org, EVENT:TIMES:
<https://www.c3d.org/HTML/Documents/eventtimes1.htm>

## See also

[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md),
[`segmentCohortCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentCohortCycles.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# `x` is a C3D object read via the c3dr package from a .c3d file.
c3dEventTable(x, event_time_reference = "trial_start")
} # }
```
