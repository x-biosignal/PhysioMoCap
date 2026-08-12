# Correct Marker Label Swaps

Repairs marker trajectories by swapping the data columns of detected
swap pairs from the swap frame onward.

## Usage

``` r
correctSwaps(pe, swaps, assay_prefix = "position", min_confidence = 0.5)
```

## Arguments

- pe:

  A PhysioExperiment with position assays.

- swaps:

  A `data.frame` as returned by
  [`detectSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectSwaps.md),
  containing at minimum `frame`, `marker_a`, `marker_b`, and
  `confidence` columns.

- assay_prefix:

  Prefix for position assay names. Default `"position"`.

- min_confidence:

  Minimum confidence threshold for applying a correction. Swaps below
  this threshold are skipped. Default 0.5.

## Value

A PhysioExperiment with corrected position assays.

## See also

[`detectSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectSwaps.md),
[`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
swaps <- detectSwaps(pe)
pe_fixed <- correctSwaps(pe, swaps, min_confidence = 0.3)
} # }
```
