# Print a MoCap readiness report

Print a MoCap readiness report

## Usage

``` r
# S3 method for class 'mocap_readiness'
print(x, ...)
```

## Arguments

- x:

  A `mocap_readiness` object from
  [`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md).

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
for computing the readiness report.

## Examples

``` r
demo <- demoMoCapData(seed = 1)
report <- assessMoCapReadiness(demo$mocap)
print(report)
#> MoCap Readiness Report
#>   Score:100% (A+)
#>   Frames: 300 
#>   Markers: 8 
#>   Checks: 8 / 8 passed
```
