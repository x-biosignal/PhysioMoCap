# Forward kinematics of a planar chain

Node positions of a serial planar chain from a base, the fixed segment
lengths and the ABSOLUTE segment angles (radians, from the x-axis).

## Usage

``` r
forwardKinematics2D(angles, lengths, base = c(0, 0))
```

## Arguments

- angles:

  Absolute segment angles (length `n_segments`).

- lengths:

  Segment lengths (length `n_segments`).

- base:

  Root position (length 2; default origin).

## Value

a `(n_segments + 1) x 2` matrix of node positions.

## See also

[`inverseKinematicsMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseKinematicsMarkers.md)

## Examples

``` r
forwardKinematics2D(c(0, pi/2), c(1, 1))           # right angle
#>      [,1] [,2]
#> [1,]    0    0
#> [2,]    1    0
#> [3,]    1    1
```
