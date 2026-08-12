# Compute joint power from moment and angular velocity

Joint power is the product of the net joint moment and the joint angular
velocity. Positive power (`generation`) reflects concentric muscle
action doing work on the segment; negative power (`absorption`) reflects
eccentric action absorbing energy. Set `split = TRUE` to return the
generation and absorption components alongside the total.

## Usage

``` r
computeJointPower(moment, angular_velocity, split = FALSE)
```

## Arguments

- moment:

  Numeric vector of joint moment values.

- angular_velocity:

  Numeric vector of joint angular velocity in rad/s.

- split:

  Logical; if `TRUE`, return a data frame with the total `power` split
  into non-negative `generation` (`P > 0`) and non-positive `absorption`
  (`P < 0`) components. Default `FALSE` returns the total power vector
  (backward compatible).

## Value

If `split = FALSE`, a numeric vector of joint power (W). If
`split = TRUE`, a data frame with columns `power`, `generation`, and
`absorption` (each in W); `generation + absorption == power`
elementwise.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
for computing joint moments in 2D,
[`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
for computing joint moments in 3D,
[`jointWork()`](https://x-biosignal.github.io/PhysioMoCap/reference/jointWork.md)
for integrating power into concentric/eccentric work,
[`labelPowerBursts()`](https://x-biosignal.github.io/PhysioMoCap/reference/labelPowerBursts.md)
for Winter power-burst nomenclature.

## Examples

``` r
computeJointPower(c(10, 12, 8), c(2, 1.5, 1))
#> [1] 20 18  8
computeJointPower(c(10, -12, 8), c(2, 1.5, -1), split = TRUE)
#>   power generation absorption
#> 1    20         20          0
#> 2   -18          0        -18
#> 3    -8          0         -8
```
