# Model-based inverse kinematics from markers (planar)

Solves the segment angles of a scaled planar chain that best fit
observed marker positions, frame by frame, by least squares. Because the
segment lengths are fixed by the model, the solution is consistent
(unlike reading angles directly off noisy markers, which lets the limb
stretch).

## Usage

``` r
inverseKinematicsMarkers(markers, model, anchor_root = TRUE)
```

## Arguments

- markers:

  A `[frame, node, 2]` array of observed node positions (root and each
  joint/end), or a list of `(n_segments + 1) x 2` matrices.

- model:

  A `planar_ik_model` from
  [`scalePlanarModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/scalePlanarModel.md).

- anchor_root:

  If `TRUE` (default) the root is fixed to the observed root marker each
  frame; otherwise the root is also fitted.

## Value

an `ik_result`: `angles` (`frame x n_segments`, absolute radians),
`rmse` (per-frame marker RMS error, in position units), and `n_frames`.

## References

Lu TW, O'Connor JJ (1999) global optimisation IK, J Biomech 32:129-134.

## See also

[`scalePlanarModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/scalePlanarModel.md),
[`forwardKinematics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/forwardKinematics2D.md)

## Examples

``` r
model <- scalePlanarModel(rbind(c(0, 0), c(1, 0), c(2, 0)))
truth <- forwardKinematics2D(c(0.3, 0.7), model$lengths)
arr <- array(0, c(1, 3, 2)); arr[1, , ] <- truth
inverseKinematicsMarkers(arr, model)$angles         # ~ c(0.3, 0.7)
#>      [,1] [,2]
#> [1,]  0.3  0.7
```
