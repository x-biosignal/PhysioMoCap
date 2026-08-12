# Project 3D coordinates to a 2D plane

Selects two of three coordinate axes based on the anatomical plane,
returning a data frame with `u` (horizontal) and `v` (vertical) columns.

## Usage

``` r
projectTo2D(x, y, z, plane = c("sagittal", "frontal", "transverse"))
```

## Arguments

- x:

  Numeric vector of X (medial-lateral) coordinates.

- y:

  Numeric vector of Y (anterior-posterior) coordinates.

- z:

  Numeric vector of Z (vertical) coordinates.

- plane:

  Character string specifying the projection plane. One of `"sagittal"`,
  `"frontal"`, or `"transverse"`.

## Value

A data frame with columns `u` and `v`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`plotSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton.md)
for 2D skeleton visualization,
[`plotSkeleton3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton3D.md)
for pseudo-3D skeleton rendering.

## Examples

``` r
proj <- projectTo2D(c(1, 2), c(3, 4), c(5, 6), plane = "sagittal")
proj$u  # Y values (anterior-posterior)
#> [1] 3 4
proj$v  # Z values (vertical)
#> [1] 5 6
```
