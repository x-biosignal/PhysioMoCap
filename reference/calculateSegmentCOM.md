# Calculate per-segment centers of mass

Lower-level function that computes the center of mass for individual
body segments from marker position data.

## Usage

``` r
calculateSegmentCOM(pe, proximal_markers, distal_markers, com_fractions)
```

## Arguments

- pe:

  A `PhysioExperiment` object with `position_x`, `position_y`, and
  optionally `position_z` assays.

- proximal_markers:

  Character vector of proximal marker names, one per segment.

- distal_markers:

  Character vector of distal marker names, one per segment (same length
  as `proximal_markers`).

- com_fractions:

  Numeric vector of COM proximal fractions (0-1), one per segment (same
  length as `proximal_markers`).

## Value

A named list of matrices, one per segment. Each matrix has dimensions
(n_frames x 2) for 2D data or (n_frames x 3) for 3D data, with columns
named `"x"`, `"y"`, and (optionally) `"z"`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md)
for whole-body center of mass,
[`segmentParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentParameters.md)
for body segment inertial parameters.

## Examples

``` r
n <- 50
mk <- function(v) { m <- matrix(v, n, 3); colnames(m) <- c("A", "B", "C"); m }
pe <- PhysioExperiment(
  assays = S4Vectors::SimpleList(position_x = mk(1), position_y = mk(2),
                                 position_z = mk(0)),
  colData = S4Vectors::DataFrame(label = c("A", "B", "C"),
                                 type = rep("marker", 3)),
  samplingRate = 100)
seg_com <- calculateSegmentCOM(pe, proximal_markers = "A",
  distal_markers = "B", com_fractions = 0.5)
names(seg_com)
#> [1] "A_to_B"
head(seg_com[[1]])
#>      x y z
#> [1,] 1 2 0
#> [2,] 1 2 0
#> [3,] 1 2 0
#> [4,] 1 2 0
#> [5,] 1 2 0
#> [6,] 1 2 0
```
