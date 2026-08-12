# Plot a skeleton frame in pseudo-3D

Renders one frame of a skeleton in a perspective-like 3D projection
using a lightweight base graphics backend (no external 3D dependency
required).

## Usage

``` r
plotSkeleton3D(
  pe,
  skeleton,
  frame = 1,
  azimuth = 35,
  elevation = 20,
  distance = 6,
  show_labels = FALSE,
  point_col = "steelblue",
  segment_col = "gray40",
  point_cex = 1.1,
  segment_lwd = 1.5,
  main = NULL,
  draw = TRUE
)
```

## Arguments

- pe:

  A PhysioExperiment object with `position_x`, `position_y`, and
  `position_z` assays.

- skeleton:

  A `SkeletonModel` object.

- frame:

  Integer frame index.

- azimuth:

  View azimuth angle in degrees.

- elevation:

  View elevation angle in degrees.

- distance:

  Perspective distance (larger = weaker perspective).

- show_labels:

  Logical; if `TRUE`, draws keypoint labels.

- point_col:

  Point color.

- segment_col:

  Segment color.

- point_cex:

  Point size.

- segment_lwd:

  Segment line width.

- main:

  Plot title. If `NULL`, auto-generated.

- draw:

  Logical; if `TRUE`, draws to current graphics device.

## Value

Invisibly returns a list with projected coordinates and view parameters.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`plotSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton.md)
for 2D skeleton visualization,
[`projectTo2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/projectTo2D.md)
for manual coordinate projection.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readOpenPose("frames/", model = "BODY_25")
sk <- define_skeleton("BODY_25")
plotSkeleton3D(pe, sk, frame = 10, azimuth = 35, elevation = 20)
} # }
```
