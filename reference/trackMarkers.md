# Track Markers Across Frames

Resolves inconsistent marker labelling across frames by establishing
frame-to-frame correspondences using the Hungarian algorithm. This is
essential for Venus3D data where marker IDs are randomly reassigned each
frame.

## Usage

``` r
trackMarkers(
  pe,
  method = "hungarian",
  max_distance = Inf,
  use_prediction = FALSE,
  assay_prefix = "position"
)
```

## Arguments

- pe:

  A PhysioExperiment with `position_x`, `position_y`, `position_z`
  assays (frames x markers).

- method:

  Assignment method: `"hungarian"` (optimal, requires the `clue`
  package) or `"greedy"` (fast approximate). Default `"hungarian"`.

- max_distance:

  Maximum allowed assignment distance. Assignments exceeding this
  threshold are set to `NA`. Default `Inf` (no limit).

- use_prediction:

  Logical. If `TRUE`, use linear velocity prediction for the reference
  positions instead of raw previous-frame positions. Improves tracking
  of fast-moving markers. Default `FALSE`.

- assay_prefix:

  Prefix for position assay names. Default `"position"`.

## Value

A PhysioExperiment where columns consistently correspond to the same
physical marker across all frames. The `metadata$tracking` list
contains:

- assignment:

  Integer matrix (frames x markers) of column indices from the original
  data used at each frame.

- cost:

  Numeric matrix (frames x markers) of assignment costs (Euclidean
  distances) at each frame.

- method:

  Character string indicating the method used.

## Details

The algorithm:

1.  Frame 1 defines the reference labelling.

2.  For each subsequent frame, a Euclidean distance cost matrix is
    computed between reference positions and observed positions.

3.  The cost matrix is solved via
    [`clue::solve_LSAP()`](https://rdrr.io/pkg/clue/man/solve_LSAP.html)
    (Hungarian algorithm) or a greedy heuristic.

4.  If marker counts differ between frames, the cost matrix is padded
    with dummy entries (cost = 1e12).

5.  Assignments exceeding `max_distance` are marked as `NA`.

6.  With `use_prediction = TRUE`, reference positions are extrapolated
    using velocity from the two preceding frames.

## References

Kuhn HW (1955). "The Hungarian Method for the Assignment Problem." Naval
Research Logistics Quarterly, 2(1-2), 83-97.

## See also

[`readVenus3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readVenus3D.md)
for reading Venus3D data,
[`detectSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectSwaps.md)
and
[`correctSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/correctSwaps.md)
for post-tracking swap repair.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readVenus3D("capture.csv")
pe_tracked <- trackMarkers(pe)

# With velocity prediction for fast movements
pe_tracked <- trackMarkers(pe, use_prediction = TRUE, max_distance = 50)
} # }
```
