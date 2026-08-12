# Plot DTW alignment

Visualizes the DTW alignment between two waveforms.

## Usage

``` r
plotDTW(
  dtw_result,
  x = NULL,
  y = NULL,
  type = c("alignment", "cost", "waveforms", "all")
)
```

## Arguments

- dtw_result:

  A dtw_result object from dtwDistance().

- x:

  First waveform (optional, for overlay).

- y:

  Second waveform (optional, for overlay).

- type:

  Plot type: "alignment", "cost", "waveforms", or "all".

## Value

A ggplot object or list of plots.

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

## See also

[`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md),
[`dtwWarp()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwWarp.md),
[`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md)
