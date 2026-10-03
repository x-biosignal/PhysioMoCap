# Print DTW result

Print DTW result

## Usage

``` r
# S3 method for class 'dtw_result'
print(x, ...)
```

## Arguments

- x:

  A dtw_result object

- ...:

  Additional arguments (unused)

## Examples

``` r
x <- sin(seq(0, pi, length.out = 100)) * 30
y <- sin(seq(0, pi, length.out = 100) + 0.3) * 30
print(dtwDistance(x, y))
#> DTW Result
#> ==========
#> Query length: 100
#> Reference length: 100
#> Distance: 24.3343
#> Normalized distance: 0.2233
#> Path length: 109
#> Step pattern: symmetric2
```
