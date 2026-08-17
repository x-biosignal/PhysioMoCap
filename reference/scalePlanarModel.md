# Scale a planar chain model from a static pose

Estimates the fixed segment lengths of a serial planar chain from the
marker positions of its nodes (joint centres and the end point) in a
static/reference pose.

## Usage

``` r
scalePlanarModel(nodes)
```

## Arguments

- nodes:

  A `(n_segments + 1) x 2` matrix of node positions (root, joint 1, ...,
  end point) in the static pose.

## Value

a `planar_ik_model`: `lengths` (per segment) and `n_segments`.

## See also

[`inverseKinematicsMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseKinematicsMarkers.md),
[`forwardKinematics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/forwardKinematics2D.md)

## Examples

``` r
nodes <- rbind(c(0, 0), c(0.4, 0), c(0.8, 0))      # two 0.4 m segments
scalePlanarModel(nodes)$lengths
#> [1] 0.4 0.4
```
