# DTW-based clustering

Clusters waveforms using DTW distance with hierarchical or k-medoids
method.

## Usage

``` r
dtwClustering(
  x,
  k = 2,
  method = c("hierarchical", "kmedoids"),
  linkage = "ward.D2",
  window_size = NULL
)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- k:

  Number of clusters.

- method:

  Clustering method: "hierarchical" or "kmedoids".

- linkage:

  For hierarchical: "ward.D2", "complete", "average", etc.

- window_size:

  Sakoe-Chiba band width.

## Value

A list containing:

- clusters:

  Cluster assignments

- centers:

  Cluster centers (medoids or DBA averages)

- distance_matrix:

  DTW distance matrix used

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

## See also

[`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md),
[`dtwDistanceMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistanceMatrix.md),
[`dtwAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwAverage.md)

## Examples

``` r
# Cluster gait patterns
set.seed(123)
t <- seq(0, 100, length.out = 100)

# Generate two groups with different patterns
group1 <- sapply(1:15, function(i) {
  sin(2 * pi * t / 100) * 30 + rnorm(100, 0, 3)
})
group2 <- sapply(1:15, function(i) {
  sin(2 * pi * t / 100 + pi/4) * 20 + rnorm(100, 0, 3)
})
data <- cbind(group1, group2)

result <- dtwClustering(data, k = 2)
table(result$clusters)
#> 
#>  1  2 
#> 15 15 
```
