# Print waveform UMAP result

Print waveform UMAP result

## Usage

``` r
# S3 method for class 'waveform_umap'
print(x, ...)
```

## Arguments

- x:

  A waveform_umap object

- ...:

  Additional arguments (unused)

## Examples

``` r
if (requireNamespace("uwot", quietly = TRUE)) {
  set.seed(1)
  d <- matrix(rnorm(1000), 100, 10)
  print(waveformUMAP(d, n_neighbors = 5))
}
#> Waveform UMAP Result
#> ====================
#> Observations: 10
#> Components: 2
#> Neighbors: 5
#> Min distance: 0.10
```
