# Compute segment lengths from a PhysioExperiment and skeleton

Calculates the Euclidean distance between connected keypoints for each
frame. The PhysioExperiment must contain `position_x`, `position_y`, and
(optionally) `position_z` assays with columns matching skeleton keypoint
labels.

## Usage

``` r
get_segment_lengths(pe, skeleton)
```

## Arguments

- pe:

  A `PhysioExperiment` object with position assays.

- skeleton:

  A `SkeletonModel` object whose keypoint labels match column names in
  the position assays.

## Value

A matrix of segment lengths with dimensions (n_frames x n_bones). Column
names are bone names.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`SkeletonModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/SkeletonModel.md),
[`get_bone_connections()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_bone_connections.md),
[`get_limb_pairs()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_limb_pairs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readOpenPose("path/to/frames/", model = "BODY_25")
sk <- define_skeleton("BODY_25")
lengths <- get_segment_lengths(pe, sk)
} # }
```
