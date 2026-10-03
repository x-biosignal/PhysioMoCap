# Print gait parameters

S3 print method showing mean +/- SD for each parameter.

## Usage

``` r
# S3 method for class 'gait_parameters'
print(x, ...)
```

## Arguments

- x:

  A `gait_parameters` object.

- ...:

  Additional arguments (unused).

## References

Perry J, Burnfield JM (2010). "Gait Analysis: Normal and Pathological
Function." 2nd ed. SLACK Incorporated.

## See also

[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for computing gait parameters,
[`summarizeGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeGaitParameters.md)
for descriptive statistics.

## Examples

``` r
demo <- demoMoCapData(seed = 1)
ev <- detectEventsZeni(demo$mocap,
  markers = list(heel_right = "Ankle_R", toe_right = "Toe_R",
                 heel_left = "Ankle_L", toe_left = "Toe_L"),
  reference = "Pelvis_R")
print(calculateGaitParameters(demo$mocap, ev))
#> Gait Parameters
#> ===============
#> Sides: right
#> Strides: 9
#> 
#>   Right side:
#>     stride_time               0.267 +/- 0.058
#>     step_time                 0.175 +/- 0.048
#>     stance_time               0.145 +/- 0.059
#>     swing_time                0.129 +/- 0.077
#>     stance_percent            54.038 +/- 23.143
#>     swing_percent             45.962 +/- 23.143
#>     double_support_time       0.139 +/- 0.074
#>     cadence                   372.604 +/- 129.820
#> 
```
