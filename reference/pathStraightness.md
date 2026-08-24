# Movement-path straightness

The straightness of a movement trajectory: the ratio of the
straight-line (direct) distance between the first and last points to the
travelled path length. A straight reach scores 1; a curved or decomposed
path scores below 1. The reciprocal (index of curvature) grows with path
irregularity, a hallmark of limb ataxia.

## Usage

``` r
pathStraightness(trajectory)
```

## Arguments

- trajectory:

  Numeric matrix of positions over time (rows = samples, columns = 1-3
  spatial axes), or a numeric vector for a single axis.

## Value

A list: `path_length`, `direct_distance`, `straightness` (direct / path,
in `(0, 1]`) and `index_of_curvature` (path / direct, `>= 1`).

## See also

[`reachingKinematics()`](https://x-biosignal.github.io/PhysioMoCap/reference/reachingKinematics.md),
[`limbAtaxiaIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/limbAtaxiaIndex.md)

## Examples

``` r
pathStraightness(cbind(c(0, 0, 1), c(0, 1, 1)))$straightness   # L-path
#> [1] 0.7071068
```
