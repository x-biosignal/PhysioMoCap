# Print a forceplate analysis summary

Print a forceplate analysis summary

## Usage

``` r
# S3 method for class 'forceplate_analysis'
print(x, ...)
```

## Arguments

- x:

  A `forceplate_analysis` object.

- ...:

  Additional arguments (ignored).

## Value

Invisibly returns `x`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for performing force plate analysis,
[`analyzeForcePlatePE()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlatePE.md)
for PhysioExperiment-based analysis.

## Examples

``` r
n <- 500
z <- matrix(0, n, 1, dimnames = list(NULL, "fp1"))
fz <- matrix(c(rep(0, 100), rep(700, 300), rep(0, 100)), n, 1,
             dimnames = list(NULL, "fp1"))
pe <- PhysioExperiment(assays = S4Vectors::SimpleList(
    force_x = z, force_y = z, force_z = fz,
    moment_x = matrix(50, n, 1, dimnames = list(NULL, "fp1")),
    moment_y = matrix(-100, n, 1, dimnames = list(NULL, "fp1")),
    moment_z = z),
  colData = S4Vectors::DataFrame(label = "fp1", type = "forceplate"),
  samplingRate = 1000)
print(analyzeForcePlatePE(pe, threshold = 20, cutoff = 20,
  filter_method = "moving_average"))
#> Forceplate analysis
#>   Stances: 1 
#>   Peak vertical force: 700 
#>   Max loading rate: 13725.49 
#>   Total impulse: 209.945 
#>   Selected plate: 1 
```
