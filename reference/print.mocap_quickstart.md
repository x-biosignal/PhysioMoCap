# Print a quick-start summary

Print a quick-start summary

## Usage

``` r
# S3 method for class 'mocap_quickstart'
print(x, ...)
```

## Arguments

- x:

  A `mocap_quickstart` object.

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`quickStartMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/quickStartMoCap.md)
for the complete getting-started workflow.

## Examples

``` r
qs <- quickStartMoCap(seed = 1)
print(qs)
#> PhysioMoCap Quick Start
#>   Source: demo 
#>   Frames: 300 
#>   Markers: 8 
#>   Sampling rate: 120.000 Hz
#>   Readiness:100% (A+)
#> 
#> Generated outputs:
#>   - velocity / acceleration: TRUE 
#>   - forceplate summary: TRUE 
#>   - inverse dynamics: TRUE 
#>   - EMG processed/aligned: TRUE / TRUE 
#> 
#> Next steps:
#>   1) Check readiness details: x$readiness
#>   2) View force summary: x$forceplate$summary
#>   3) Start from your own file: quickStartMoCap(path = 'trial.c3d')
```
