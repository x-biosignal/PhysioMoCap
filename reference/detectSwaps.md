# Detect Marker Label Swaps

Identifies frames where two or more marker trajectories abruptly swap
positions, indicating a labelling error. Swaps are detected by velocity
spikes that exceed `median + 5 * MAD` and show a cross-over pattern
between marker pairs.

## Usage

``` r
detectSwaps(pe, threshold = NULL, window = 5, assay_prefix = "position")
```

## Arguments

- pe:

  A PhysioExperiment with position assays.

- threshold:

  Velocity threshold for spike detection. If `NULL` (default), computed
  as `median + 5 * MAD` of each marker's velocity.

- window:

  Number of frames around a spike to check for cross-over patterns.
  Default 5.

- assay_prefix:

  Prefix for position assay names. Default `"position"`.

## Value

A `data.frame` with columns:

- frame:

  Frame index where the swap was detected.

- marker_a:

  Name or index of the first marker in the swap pair.

- marker_b:

  Name or index of the second marker.

- velocity_a:

  Velocity of marker_a at the swap frame.

- velocity_b:

  Velocity of marker_b at the swap frame.

- confidence:

  Confidence score (0-1) based on how closely the cross-over distances
  match.

If no swaps are detected, an empty data.frame with the same columns is
returned.

## See also

[`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md),
[`correctSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/correctSwaps.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readVenus3D("capture.csv")
pe_tracked <- trackMarkers(pe)
swaps <- detectSwaps(pe_tracked)
if (nrow(swaps) > 0) {
  pe_fixed <- correctSwaps(pe_tracked, swaps)
}
} # }
```
