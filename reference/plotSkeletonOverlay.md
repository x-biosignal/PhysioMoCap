# Plot overlaid skeleton frames

Draws multiple frames on the same plot. Earlier frames are rendered with
lower opacity when `alpha_decay = TRUE`.

## Usage

``` r
plotSkeletonOverlay(
  pe,
  skeleton,
  frames,
  plane = c("sagittal", "frontal", "transverse"),
  alpha_decay = TRUE,
  base_alpha = 0.2,
  show_labels = FALSE,
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

- frames:

  Integer vector of frame indices to overlay.

- plane:

  Anatomical plane for projection: `"sagittal"` (drop X), `"frontal"`
  (drop Y), or `"transverse"` (drop Z).

- alpha_decay:

  Logical; if `TRUE`, earlier frames have lower opacity (linearly from
  0.2 to 1.0).

- base_alpha:

  Minimum alpha for the earliest frame (default 0.2).

- show_labels:

  Logical; annotate markers with their labels.

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

## See also

[`plotSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton.md)
for single-frame skeleton visualization,
[`plotSkeletonSequence()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonSequence.md)
for multi-frame faceted display.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readOpenPose("frames/", model = "BODY_25")
sk <- define_skeleton("BODY_25")
plotSkeletonOverlay(pe, sk, frames = c(1, 5, 10, 15, 20))
} # }
```
