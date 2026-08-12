# Calculate step symmetry from gait parameters

Computes symmetry metrics comparing left and right sides. Includes the
Robinson Symmetry Index and the left/right ratio for each parameter.

## Usage

``` r
calculateStepSymmetry(gait_params)
```

## Arguments

- gait_params:

  A `gait_parameters` object from
  [`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
  containing both left and right sides.

## Value

A data.frame with columns:

- parameter:

  Name of the gait parameter

- left_mean:

  Mean value for the left side

- right_mean:

  Mean value for the right side

- SI:

  Robinson Symmetry Index: `|L - R| / (0.5 * (L + R)) * 100`

- ratio:

  Left / Right ratio

## Details

A Symmetry Index (SI) of 0 indicates perfect symmetry. Values above 10
are generally considered clinically asymmetric.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for computing gait temporal-spatial parameters,
[`symmetryIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/symmetryIndex.md)
for general symmetry index computation,
[`plotSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSymmetry.md)
for symmetry visualization.

## Examples

``` r
# See test file for worked examples
```
