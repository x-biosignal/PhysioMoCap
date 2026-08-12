# Summarise gait parameters

Computes mean, standard deviation, and coefficient of variation for each
gait parameter across all strides.

## Usage

``` r
summarizeGaitParameters(gait_params)
```

## Arguments

- gait_params:

  A `gait_parameters` object.

## Value

A data.frame with columns `parameter`, `side`, `mean`, `sd`, and `cv`
(coefficient of variation as percentage).

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for computing gait parameters,
[`print.gait_parameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.gait_parameters.md)
for formatted display of results.

## Examples

``` r
# See test file for worked examples
```
