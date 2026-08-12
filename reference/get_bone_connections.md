# Get bone connections from a skeleton

Returns the bone connections as an edge list (data.frame) or as an
adjacency matrix.

## Usage

``` r
get_bone_connections(skeleton, as_matrix = FALSE)
```

## Arguments

- skeleton:

  A `SkeletonModel` object.

- as_matrix:

  Logical. If `TRUE`, return a square adjacency matrix with keypoint
  labels as row/column names. Default `FALSE`.

## Value

If `as_matrix = FALSE`, a `data.frame` with columns `from_label`,
`to_label`, and `bone_name`. If `as_matrix = TRUE`, a symmetric logical
adjacency matrix.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`SkeletonModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/SkeletonModel.md),
[`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md),
[`get_segment_lengths()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_segment_lengths.md)

## Examples

``` r
sk <- define_skeleton("COCO")
edges <- get_bone_connections(sk)
head(edges)
#>   from_label  to_label       bone_name
#> 1       Neck RShoulder  right_clavicle
#> 2       Neck LShoulder   left_clavicle
#> 3  RShoulder    RElbow right_upper_arm
#> 4     RElbow    RWrist   right_forearm
#> 5  LShoulder    LElbow  left_upper_arm
#> 6     LElbow    LWrist    left_forearm

adj <- get_bone_connections(sk, as_matrix = TRUE)
dim(adj)
#> [1] 18 18
```
