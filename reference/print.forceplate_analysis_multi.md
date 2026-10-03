# Print a multi-plate forceplate analysis summary

Print a multi-plate forceplate analysis summary

## Usage

``` r
# S3 method for class 'forceplate_analysis_multi'
print(x, ...)
```

## Arguments

- x:

  A `forceplate_analysis_multi` object.

- ...:

  Additional arguments (ignored).

## Value

Invisibly returns `x`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlatePE()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlatePE.md)
for multi-plate force plate analysis,
[`print.forceplate_analysis()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.forceplate_analysis.md)
for single-plate result display.

## Examples

``` r
n <- 500
lab <- c("fp1", "fp2")
z <- matrix(0, n, 2, dimnames = list(NULL, lab))
fz <- matrix(c(rep(0, 100), rep(700, 300), rep(0, 100)), n, 2,
             dimnames = list(NULL, lab))
pe <- PhysioExperiment(assays = S4Vectors::SimpleList(
    force_x = z, force_y = z, force_z = fz,
    moment_x = matrix(50, n, 2, dimnames = list(NULL, lab)),
    moment_y = matrix(-100, n, 2, dimnames = list(NULL, lab)),
    moment_z = z),
  colData = S4Vectors::DataFrame(label = lab, type = c("forceplate", "forceplate")),
  samplingRate = 1000)
print(analyzeForcePlatePE(pe, plate_index = "all", threshold = 20,
  cutoff = 20, filter_method = "moving_average"))
#> Forceplate analysis (multi-plate)
#>   Plates: 2 
#>   Sampling rate: 1000 Hz
#> 
#> Summary by plate:
#>   plate peak_vertical_force max_loading_rate total_impulse n_stances
#>  plate1                 700         13725.49      209.9451         1
#>  plate2                 700         13725.49      209.9451         1
```
