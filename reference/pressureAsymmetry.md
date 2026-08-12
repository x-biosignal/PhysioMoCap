# Compare left and right plantar pressure

Calculates the signed Robinson symmetry index: \$\$100 (L-R) /
((L+R)/2).\$\$

## Usage

``` r
pressureAsymmetry(
  left,
  right,
  metric = c("peak_pressure", "pti", "contact_area", "total_force"),
  force_factor = 0.001
)
```

## Arguments

- left, right:

  Left and right `pressure_movie` objects.

- metric:

  Scalar metric to compare.

- force_factor:

  Conversion from pressure times cell area to force.

## Value

A `pressure_asymmetry` object containing side values, signed and
absolute symmetry indices, and the left/right ratio.

## References

Robinson RO, Herzog W, Nigg BM (1987). Use of force platform variables
to quantify the effects of chiropractic manipulation on gait symmetry.
*Journal of Manipulative and Physiological Therapeutics*, 10:172-176.

## Examples

``` r
left <- pressureMovie(array(100, c(3, 3, 5)), 100, side = "left")
right <- pressureMovie(array(80, c(3, 3, 5)), 100, side = "right")
pressureAsymmetry(left, right)
#> <pressure_asymmetry> metric=peak_pressure
#>   left: 100  right: 80  SI: 22.22%  |SI|: 22.22%
```
