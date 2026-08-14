# Standardise segment lengths (camera-distance correction)

In 2D video, apparent bone lengths shrink and grow as the subject moves
toward or away from the camera, biasing kinematics. This rescales each
limb segment so its length matches a stable reference (the recording's
median or mean of that segment), repositioning the distal keypoint along
the bone direction and chaining proximal to distal. Generalised form of
the length correction in PoseFixeR (Sugiyama, Uno & Matsui 2023).

## Usage

``` r
poseLengthCorrect(pe, chains = NULL, reference = c("median", "mean"))
```

## Arguments

- pe:

  A pose `PhysioExperiment` (assays `keypoint_x`, `keypoint_y`;
  `colData$label`), e.g. from
  [`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)
  or after
  [`poseFix()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseFix.md).

- chains:

  Optional list of kinematic chains, each a proximal-to-distal vector of
  keypoint names (default: both legs and both arms, restricted to the
  present keypoints).

- reference:

  `"median"` (default, robust) or `"mean"` reference length.

## Value

A `PhysioExperiment` with length-standardised `keypoint_x`/`y`;
`metadata()$poseLengthCorrect` holds the reference length per segment.

## References

Sugiyama S, Uno K, Matsui Y (2023). *PLOS Comput Biol* 19:e1009989.
[doi:10.1371/journal.pcbi.1009989](https://doi.org/10.1371/journal.pcbi.1009989)

## See also

[`poseFix()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseFix.md)
