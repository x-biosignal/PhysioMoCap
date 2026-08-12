# Peak reaching velocity

Peak reaching velocity

## Usage

``` r
peakVelocity(speed)
```

## Arguments

- speed:

  Numeric non-negative tangential-speed profile.

## Value

Peak speed. Its first 1-based sample index is stored in the `"index"`
attribute. Returns `NA` when all samples are missing.

## Examples

``` r
peakVelocity(c(0, 1, 3, 2, 0))
#> [1] 3
#> attr(,"index")
#> [1] 3
```
