# Dynamic Time Warping (DTW) for Biomechanics

Functions for Dynamic Time Warping analysis including distance
computation, alignment, averaging, and clustering of biomechanical
waveforms. Compute DTW distance between two time series

## Usage

``` r
dtwDistance(
  x,
  y,
  window_size = NULL,
  step_pattern = c("symmetric2", "symmetric1", "asymmetric"),
  normalize = TRUE
)
```

## Arguments

- x:

  First time series (numeric vector or matrix column).

- y:

  Second time series (numeric vector or matrix column).

- window_size:

  Sakoe-Chiba band width (NULL for no constraint).

- step_pattern:

  Step pattern: "symmetric1", "symmetric2", or "asymmetric".

- normalize:

  Logical; whether to normalize distance by path length.

## Value

A list of class "dtw_result" containing:

- distance:

  DTW distance

- normalized_distance:

  Distance normalized by path length

- path:

  Alignment path (matrix with columns 'index1', 'index2')

- cost_matrix:

  Accumulated cost matrix

## Details

Calculates the Dynamic Time Warping distance and alignment path between
two waveforms, allowing for non-linear time alignment.

DTW finds the optimal alignment between two time series by warping the
time axis. It's useful for comparing movements that may occur at
different speeds or with timing differences.

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

## See also

[`dtwDistanceMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistanceMatrix.md),
[`dtwAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwAverage.md),
[`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md),
[`dtwWarp()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwWarp.md)

## Examples

``` r
# Two gait cycles with different timing
t <- seq(0, 100, length.out = 100)
x <- sin(2 * pi * t / 100) * 30
y <- sin(2 * pi * (t + 10) / 100) * 30  # Phase shifted

result <- dtwDistance(x, y)
print(result$distance)
#> [1] 48.8402
```
