# Plot a sequence of skeleton frames

Creates a multi-panel faceted plot showing the skeleton at several
frames.

## Usage

``` r
plotSkeletonSequence(
  pe,
  skeleton,
  frames,
  plane = c("sagittal", "frontal", "transverse"),
  ncol = 3,
  show_labels = FALSE,
  show_confidence = FALSE,
  point_size = 2,
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

  Integer vector of frame indices to plot.

- plane:

  Anatomical plane for projection: `"sagittal"` (drop X), `"frontal"`
  (drop Y), or `"transverse"` (drop Z).

- ncol:

  Number of columns in the faceted layout (default 3).

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

A ggplot object with facets.

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

## See also

[`plotSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton.md)
for single-frame skeleton visualization,
[`plotSkeletonOverlay()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonOverlay.md)
for overlaid frames on a single plot.

## Examples

``` r
sk <- define_skeleton("BODY_25")
labels <- sk$keypoints$label
set.seed(42)
nk <- length(labels); nf <- 10
mk <- function(b) matrix(rep(b, each = nf), nf)
px <- mk(rnorm(nk, 0, 0.3)); py <- mk(rnorm(nk, 0, 0.3))
pz <- mk(seq(1.8, 0, length.out = nk))
colnames(px) <- colnames(py) <- colnames(pz) <- labels
pe <- PhysioExperiment(assays = S4Vectors::SimpleList(
    position_x = px, position_y = py, position_z = pz),
  colData = S4Vectors::DataFrame(label = labels, type = rep("keypoint", nk)),
  samplingRate = 30)
plotSkeletonSequence(pe, sk, frames = c(1, 5, 10))
```
