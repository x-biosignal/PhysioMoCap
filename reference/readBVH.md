# Read BVH Skeleton Animation File (.bvh)

Reads a BVH (Biovision Hierarchy) file containing skeleton animation
data. BVH files have two sections: HIERARCHY (joint tree structure with
offsets and channel definitions) and MOTION (frame data). The ROOT joint
has 6 channels (3 position + 3 rotation), while child JOINTs have 3
channels (rotation only).

## Usage

``` r
readBVH(path)
```

## Arguments

- path:

  Character string giving the path to the `.bvh` file.

## Value

A `PhysioExperiment` object with rotation assays (`rotation_x`,
`rotation_y`, `rotation_z`) for all joints, and position assays
(`position_x`, `position_y`, `position_z`) for the root joint. `colData`
includes joint names (`label`), channel type (`type`), and
`parent_joint`. `metadata` includes `bvh_skeleton` (hierarchy tree),
`rotation_order`, `frame_time`, `offsets`, and `source_file`.
`samplingRate` is computed as `1 / frame_time`.

## References

Meredith M, Maddock S (2001). "Motion Capture File Formats Explained."
Department of Computer Science, University of Sheffield.

## See also

[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md),
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)

## Examples

``` r
bvh_file <- system.file("testdata", "sample.bvh", package = "PhysioMoCap")
if (nzchar(bvh_file)) {
  pe <- readBVH(bvh_file)
  pe
}
#> class: PhysioExperiment
#> dim: 3 x 2 
#> assays(6): rotation_x, rotation_y, rotation_z ...
#> samplingRate: 30.0003 Hz
#> channels(2): Hips, RightKnee
#> colData names(3): label, type, parent_joint
```
