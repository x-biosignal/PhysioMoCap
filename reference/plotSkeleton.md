# Plot a 2D stick-figure skeleton

Draws a single frame from a PhysioExperiment as a 2D stick figure by
projecting 3D marker positions onto an anatomical plane.

## Usage

``` r
plotSkeleton(
  pe,
  skeleton,
  frame = 1,
  plane = c("sagittal", "frontal", "transverse"),
  show_labels = FALSE,
  show_confidence = FALSE,
  point_size = 3,
  segment_color = "gray40",
  title = NULL
)
```

## Arguments

- pe:

  A PhysioExperiment object with `position_x`, `position_y`, and
  `position_z` assays (columns named by keypoint label).

- skeleton:

  A `SkeletonModel` object whose keypoint labels match column names in
  the position assays.

- frame:

  Integer frame (row) index to plot (default 1).

- plane:

  Anatomical plane for projection: `"sagittal"` (drop X), `"frontal"`
  (drop Y), or `"transverse"` (drop Z).

- show_labels:

  Logical; annotate markers with their labels.

- show_confidence:

  Logical; color markers by confidence if a `confidence` assay is
  present.

- point_size:

  Marker point size (default 3).

- segment_color:

  Color for bone segments (default `"gray40"`).

- title:

  Plot title. If `NULL`, auto-generated.

## Value

A ggplot object.

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`plotSkeletonSequence()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonSequence.md)
for multi-frame faceted display,
[`plotSkeletonOverlay()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonOverlay.md)
for overlaid motion visualization,
[`plotSkeleton3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton3D.md)
for pseudo-3D rendering,
[`projectTo2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/projectTo2D.md)
for coordinate projection utilities.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readOpenPose("frames/", model = "BODY_25")
sk <- define_skeleton("BODY_25")
plotSkeleton(pe, sk, frame = 1, plane = "frontal")
} # }
```
