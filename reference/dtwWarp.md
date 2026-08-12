# Warp a waveform using DTW alignment

Applies a DTW alignment path to warp one waveform to match another.

## Usage

``` r
dtwWarp(x, dtw_result, to = c("query", "reference"))
```

## Arguments

- x:

  Waveform to warp.

- dtw_result:

  DTW result from dtwDistance().

- to:

  Which series to warp to: "query" (index1) or "reference" (index2).

## Value

Warped waveform.

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

## See also

[`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md),
[`dtwAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwAverage.md),
[`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md)
