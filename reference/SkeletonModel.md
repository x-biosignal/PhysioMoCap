# Create a SkeletonModel object

Constructs an S3 `SkeletonModel` object that defines a skeleton topology
for pose estimation or motion capture data. A skeleton consists of named
keypoints (joints/markers), bones connecting them, and an optional
hierarchical tree structure.

## Usage

``` r
SkeletonModel(name, keypoints, bones, hierarchy, root_keypoint)
```

## Arguments

- name:

  Character string identifying the skeleton model (e.g., `"BODY_25"`,
  `"COCO"`).

- keypoints:

  A `data.frame` with columns:

  id

  :   Integer, 0-indexed keypoint identifier.

  label

  :   Character, human-readable keypoint name.

  body_region

  :   Character, anatomical region (e.g., `"head"`, `"torso"`,
      `"left_arm"`).

- bones:

  A `data.frame` with columns:

  from_id

  :   Integer, source keypoint id.

  to_id

  :   Integer, target keypoint id.

  bone_name

  :   Character, descriptive name for the bone segment.

- hierarchy:

  Named list of parent-to-children relationships. Each element name is a
  parent keypoint label; the value is a character vector of child
  keypoint labels.

- root_keypoint:

  Character, label of the root keypoint in the hierarchy (e.g.,
  `"MidHip"` for BODY_25).

## Value

A `SkeletonModel` object (S3 class).

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md),
[`get_bone_connections()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_bone_connections.md),
[`get_segment_lengths()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_segment_lengths.md)

## Examples

``` r
# Minimal skeleton
kp <- data.frame(
  id = 0:2,
  label = c("Head", "Torso", "Hip"),
  body_region = c("head", "torso", "pelvis")
)
bones <- data.frame(
  from_id = c(0, 1),
  to_id = c(1, 2),
  bone_name = c("neck", "spine")
)
hier <- list(Head = "Torso", Torso = "Hip")
sk <- SkeletonModel("mini", kp, bones, hier, "Head")
print(sk)
#> SkeletonModel: mini 
#>   Keypoints: 3 
#>   Bones:     2 
#>   Root:      Head 
#>   Regions:   head, torso, pelvis 
```
