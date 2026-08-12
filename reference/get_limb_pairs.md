# Get left/right limb pairs for symmetry analysis

Identifies corresponding left and right keypoint pairs in a skeleton
model, useful for bilateral symmetry analysis.

## Usage

``` r
get_limb_pairs(skeleton)
```

## Arguments

- skeleton:

  A `SkeletonModel` object.

## Value

A `data.frame` with columns `left` and `right`, where each row is a
matched pair of keypoint labels.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`SkeletonModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/SkeletonModel.md),
[`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md),
[`get_segment_lengths()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_segment_lengths.md)

## Examples

``` r
sk <- define_skeleton("BODY_25")
pairs <- get_limb_pairs(sk)
head(pairs)
#>        left     right
#> 1 LShoulder RShoulder
#> 2    LElbow    RElbow
#> 3    LWrist    RWrist
#> 4      LHip      RHip
#> 5     LKnee     RKnee
#> 6    LAnkle    RAnkle
```
