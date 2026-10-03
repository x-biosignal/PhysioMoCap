# Calculate whole-body center of mass from marker positions

Computes the whole-body center of mass (COM) at each time frame from 3D
(or 2D) marker position data and body segment inertial parameters.

## Usage

``` r
calculateCOM(pe, body_mass, skeleton = NULL, bsip = NULL, marker_map = NULL)
```

## Arguments

- pe:

  A `PhysioExperiment` object containing `position_x`, `position_y`, and
  optionally `position_z` assays.

- body_mass:

  Numeric scalar, body mass in kilograms. Must be positive.

- skeleton:

  Optional `SkeletonModel` object used for automatic marker mapping. If
  provided and `marker_map` is `NULL`, a default mapping is generated
  from the skeleton model.

- bsip:

  Optional data.frame of body segment parameters (as returned by
  [`segmentParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentParameters.md)).
  If `NULL` (default), uses `segmentParameters("deLeva_male")`.

- marker_map:

  Optional named list mapping each segment to its proximal and distal
  marker names. Each element should be a character vector of length 2:
  `c(proximal_marker, distal_marker)`. Segment names must match those in
  the `bsip` table. Example:
  `list(thigh_r = c("RHip", "RKnee"), thigh_l = c("LHip", "LKnee"))`.

## Value

A `PhysioExperiment` object with additional assays `com_x`, `com_y`, and
(if 3D) `com_z`. Each assay is a single-column matrix with column name
`"COM"` and the same number of rows as the input.

## Details

The algorithm proceeds as follows:

1.  For each body segment, compute the segment COM position as:
    \$\$COM\_{seg} = P\_{prox} + f \times (P\_{dist} - P\_{prox})\$\$
    where \\f\\ is the COM proximal fraction from the BSIP table.

2.  Compute the whole-body COM as the mass-weighted average of all
    segment COMs: \$\$COM\_{body} = \frac{\sum_i m_i \times
    COM_i}{M}\$\$ where \\m_i = M \times f_i\\ is the segment mass and
    \\M\\ is the total body mass.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

Zatsiorsky VM (2002). "Kinetics of Human Motion." Human Kinetics.

## See also

[`segmentParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentParameters.md)
for body segment inertial parameters,
[`calculateSegmentCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateSegmentCOM.md)
for individual segment center of mass,
[`symmetryIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/symmetryIndex.md)
for bilateral symmetry assessment.

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
bsip <- data.frame(segment = c("s1", "s2"), mass_fraction = c(50, 50),
  com_proximal_fraction = c(0.5, 0.5),
  proximal_marker = c("A", "B"), distal_marker = c("B", "C"),
  stringsAsFactors = FALSE)
pe_com <- calculateCOM(pe, body_mass = 70, bsip = bsip,
  marker_map = list(s1 = c("A", "B"), s2 = c("B", "C")))
SummarizedExperiment::assayNames(pe_com)
#> [1] "com_x" "com_y" "com_z"
```
