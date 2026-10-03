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
  [`PhysioExperiment::samplingRate()`](https://x-biosignal.r-universe.dev/PhysioExperiment/reference/samplingRate.html).

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
demo <- demoMoCapData(seed = 1)
rk <- reachingKinematics(demo$mocap, marker = "Toe_R")
names(rk)
#>  [1] "movement_time"      "peak_velocity"      "time_to_peak"      
#>  [4] "time_to_peak_frac"  "n_movement_units"   "sparc"             
#>  [7] "ldlj"               "dimensionless_jerk" "onset"             
#> [10] "offset"             "fs"                 "marker"            
```
