# Reaching kinematics report for a PhysioExperiment

Extracts a hand-marker trajectory, computes tangential speed with
[`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
and
[`computeSpeed()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeSpeed.md),
and reports temporal, submovement, smoothness, endpoint, and optional
trunk-compensation metrics.

## Usage

``` r
reachingKinematics(
  pe,
  marker,
  target = NULL,
  assay_prefix = "position",
  sampling_rate = NULL,
  onset_threshold = 0.05,
  trunk_marker = NULL,
  shoulder_markers = NULL,
  ...
)
```

## Arguments

- pe:

  A `PhysioExperiment` with `position_x`, `position_y`, and optionally
  `position_z` assays.

- marker:

  Reaching hand marker name or column index.

- target:

  Optional target coordinate matching trajectory dimension.

- assay_prefix:

  Position-assay prefix (default `"position"`).

- sampling_rate:

  Optional sampling frequency in Hz; defaults to
  [`PhysioCore::samplingRate()`](https://x-biosignal.github.io/PhysioCore//reference/samplingRate.html).

- onset_threshold:

  Movement threshold.

- trunk_marker:

  Optional trunk marker name or column index.

- shoulder_markers:

  Optional length-2 vector identifying right and left shoulder markers.

- ...:

  Additional arguments passed to
  [`sparc()`](https://x-biosignal.github.io/PhysioMoCap/reference/sparc.md).

## Value

A `reaching_kinematics` report with movement time, peak velocity, time
to peak, movement units, SPARC, LDLJ, dimensionless jerk, movement
bounds, sampling rate, marker, and optional endpoint/trunk results.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 200, n_markers = 3, sr = 200)
reachingKinematics(pe, marker = "Marker1")
} # }
```
