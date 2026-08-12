# Compute bilateral symmetry index

Calculates a symmetry index between left and right side measurements
using standard methods from the biomechanics literature.

## Usage

``` r
symmetryIndex(left, right, method = "robinson")
```

## Arguments

- left:

  Numeric vector or matrix of left-side values.

- right:

  Numeric vector or matrix of right-side values (same dimensions as
  `left`).

- method:

  Character string specifying the symmetry index method. `"robinson"`
  (default): Robinson (1987) symmetry index \\SI = \|L - R\| / (0.5
  \times (L + R)) \times 100\\. `"ratio"`: simple ratio \\L / R\\.

## Value

For vectors, a numeric vector of symmetry indices. For matrices,
row-wise symmetry indices (a numeric vector of length equal to
`nrow(left)`).

## Details

The Robinson (1987) symmetry index returns 0 for perfect symmetry and
larger values for greater asymmetry. It is expressed as a percentage.
The ratio method returns 1.0 for perfect symmetry.

## References

Robinson, R.O., Herzog, W., & Nigg, B.M. (1987). Use of force platform
variables to quantify the effects of chiropractic manipulation on gait
symmetry. *Journal of Manipulative and Physiological Therapeutics*,
10(4), 172-176.

## See also

[`calculateStepSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateStepSymmetry.md)
for gait-specific symmetry metrics,
[`plotSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSymmetry.md)
for symmetry visualization,
[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for comprehensive gait analysis.

## Examples

``` r
# Perfect symmetry
symmetryIndex(10, 10)   # returns 0
#> [1] 0

# Known asymmetry
symmetryIndex(10, 8)    # returns ~22.2%
#> [1] 22.22222

# Ratio method
symmetryIndex(10, 8, method = "ratio")  # returns 1.25
#> [1] 1.25
```
