# Rayleigh test for a preferred direction

Tests the null hypothesis that the angles are uniformly distributed on
the circle (no preferred direction) against a unimodal concentration. A
small p-value means the angles cluster around a mean direction – e.g.
that a coupling angle is consistently in-phase rather than random.

## Usage

``` r
rayleighTest(angles, units = c("degrees", "radians"))
```

## Arguments

- angles:

  Numeric vector of angles.

- units:

  `"degrees"` (default) or `"radians"`.

## Value

an `htest`: Rayleigh `Z = n * rbar^2`, `p.value` (Zar 1999
approximation), and the estimated mean direction.

## References

Zar JH (1999) eq. 27.2-27.4; Fisher NI (1993).

## See also

[`circularSummary()`](https://x-biosignal.github.io/PhysioMoCap/reference/circularSummary.md),
[`watsonWilliamsTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/watsonWilliamsTest.md)

## Examples

``` r
set.seed(1)
rayleighTest(rnorm(40, mean = 30, sd = 12))$p.value   # clustered -> small
#> [1] 4.257975e-16
```
