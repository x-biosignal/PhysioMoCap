# Compute DTW distance matrix

Computes pairwise DTW distances between all columns of a matrix or
between observations in a PhysioExperiment.

## Usage

``` r
dtwDistanceMatrix(x, window_size = NULL, normalize = TRUE, parallel = FALSE)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- window_size:

  Sakoe-Chiba band width constraint.

- normalize:

  Logical; normalize by path length.

- parallel:

  Logical; use parallel processing.

## Value

A symmetric distance matrix.

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

## See also

[`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md),
[`dtwAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwAverage.md),
[`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md)

## Examples

``` r
# Create matrix of 10 gait cycles
set.seed(123)
t <- seq(0, 100, length.out = 100)
data <- sapply(1:10, function(i) {
  phase <- rnorm(1, 0, 10)
  sin(2 * pi * (t + phase) / 100) * 30 + rnorm(100, 0, 2)
})

dist_matrix <- dtwDistanceMatrix(data)
```
