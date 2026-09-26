# Summarize matched cycles into keyed feature blocks

Applies the selected modality's feature function to each native-grid
segment and preserves its observation keys. A row is one cycle, not an
independent participant. This function does not fit statistical models
or enforce grouped train/test splits. Retain participant identifiers
when building such analyses.

## Usage

``` r
summarizeCycleFeatures(x, FUN, ..., incomplete = c("error", "exclude"))
```

## Arguments

- x:

  Result of
  [`segmentMultimodalCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentMultimodalCycles.md)
  or
  [`segmentCohortCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentCohortCycles.md).

- FUN:

  Function, or a uniquely named list of functions matching modalities.
  Each function accepts a time-by-channel matrix and returns a nonempty,
  uniquely named, finite real numeric vector. Feature names must match
  across cycles within each modality; their order is reconciled by name.
  The function must handle the native grid appropriately; sampling rates
  are not equalized and samples are not weighted by duration
  automatically. Bind rate-dependent settings in per-modality functions
  using the recording metadata; metadata are not passed as implicit
  arguments to `FUN`.

- ...:

  Additional arguments passed to `FUN`.

- incomplete:

  `"error"` (default) or explicit `"exclude"`. Exclusion removes a cycle
  from all blocks if any modality was incomplete.

## Value

List with numeric matrix `blocks`, matching per-modality key tables
`keys`, retained cycle `observations`, all original `status` rows,
`cycle_rows` and `excluded_cycles` (original cycle row indices), and
`recordings` metadata. Blocks and keys can be passed to
PhysioCrossModal's keyed block adapter. No invalid cycle is silently
imputed or treated as a complete observation.

## See also

[`segmentMultimodalCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentMultimodalCycles.md)

## Examples

``` r
# Given segmented cycles z and appropriately named matrix columns:
# features <- summarizeCycleFeatures(z, colMeans)
```
