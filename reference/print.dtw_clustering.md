# Print DTW clustering result

Print DTW clustering result

## Usage

``` r
# S3 method for class 'dtw_clustering'
print(x, ...)
```

## Arguments

- x:

  A dtw_clustering object

- ...:

  Additional arguments (unused)

## Examples

``` r
set.seed(123)
tt <- seq(0, 2 * pi, length.out = 50)
g1 <- sapply(1:5, function(i) sin(tt) + rnorm(50, 0, 0.1))
g2 <- sapply(1:5, function(i) cos(tt) + rnorm(50, 0, 0.1))
print(dtwClustering(cbind(g1, g2), k = 2))
#> DTW Clustering Result
#> ====================
#> Observations: 10
#> Clusters: 2
#> 
#> Cluster sizes:
#> 
#> 1 2 
#> 5 5 
```
