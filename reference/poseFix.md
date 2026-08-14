# Detect and correct pose-estimation anomalies

Cleans a markerless-pose recording (e.g. from
[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md))
by detecting biomechanically implausible keypoints and correcting them,
connecting pose estimation to the downstream joint-angle / gait /
kinematics analysis. Anomalies are flagged from four criteria (after
Sugiyama, Uno & Matsui 2023): low detector confidence; segment (bone)
lengths that deviate from the subject's own median; frame-to-frame jumps
larger than a fraction of body scale; and joint angles outside their
empirical range. Flagged coordinates are set to `NA`, linearly
interpolated, and optionally smoothed. References are derived from the
recording itself, so the method is model-agnostic.

## Usage

``` r
poseFix(
  pe,
  conf_threshold = 0.2,
  length_tol = 0.4,
  jump_tol = 0.5,
  angle_range = c(0.01, 0.99),
  skeleton = NULL,
  joints = NULL,
  smooth = TRUE,
  smooth_spar = 0.4
)
```

## Arguments

- pe:

  A `PhysioExperiment` of pose keypoints with assays `keypoint_x`,
  `keypoint_y` and (optionally) `confidence`, and `colData$label` naming
  the keypoints — the output of
  [`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)
  /
  [`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md).

- conf_threshold:

  Keypoints with confidence below this are flagged (default 0.2).

- length_tol:

  A bone is flagged when its length deviates from its own median by more
  than this fraction (default 0.4).

- jump_tol:

  A keypoint is flagged when its frame-to-frame displacement exceeds
  this fraction of body scale (default 0.5).

- angle_range:

  Lower/upper quantiles bounding plausible joint angles (default
  `c(0.01, 0.99)`).

- skeleton:

  Optional list of `c(from, to)` keypoint-name bone pairs (default: a
  standard body skeleton restricted to the present keypoints).

- joints:

  Optional list of `c(a, b, c)` angle triplets (angle at `b`).

- smooth:

  If `TRUE` (default) smooth each coordinate with a spline after
  interpolation.

- smooth_spar:

  Smoothing parameter passed to
  [`stats::smooth.spline()`](https://rdrr.io/r/stats/smooth.spline.html).

## Value

A cleaned `PhysioExperiment` (corrected `keypoint_x`/`keypoint_y`
assays); `metadata()$poseFix` holds the per-criterion anomaly counts,
the `flagged` frame-by-keypoint logical matrix, and the flagged
fraction.

## References

Sugiyama S, Uno K, Matsui Y (2023). Types of anomalies in
two-dimensional video-based gait analysis in uncontrolled environments.
*PLOS Computational Biology* 19:e1009989.
[doi:10.1371/journal.pcbi.1009989](https://doi.org/10.1371/journal.pcbi.1009989)

## See also

[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md),
[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md)
