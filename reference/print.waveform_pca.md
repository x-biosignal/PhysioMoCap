# Print waveform PCA result

Print waveform PCA result

## Usage

``` r
# S3 method for class 'waveform_pca'
print(x, ...)
```

## Arguments

- x:

  A waveform_pca object

- ...:

  Additional arguments (unused)

## Examples

``` r
set.seed(1)
d <- matrix(rnorm(1000), 100, 10)
print(waveformPCA(d, method = "features"))
#> Waveform PCA Result
#> ===================
#> Observations: 10
#> Features: 16
#> Components retained: 9
#> 
#> Variance explained:
#>   PC1: 40.6% (cumulative: 40.6%)
#>   PC2: 27.2% (cumulative: 67.8%)
#>   PC3: 14.6% (cumulative: 82.4%)
#>   PC4: 9.5% (cumulative: 91.9%)
#>   PC5: 3.2% (cumulative: 95.1%)
```
