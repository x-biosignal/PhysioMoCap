# Mardia's circular-linear correlation

The association between an angular variable (e.g. a coupling angle or
relative phase) and a linear one (e.g. speed, force, a clinical score).
Symmetric under rotation of the angle.

## Usage

``` r
circularLinearCorrelation(theta, x, units = c("degrees", "radians"))
```

## Arguments

- theta:

  Numeric angular variable.

- x:

  Numeric linear variable (same length as `theta`).

- units:

  `"degrees"` (default) or `"radians"` for `theta`.

## Value

an `htest`: the circular-linear correlation `r` (`estimate`), the test
statistic `n * r^2 ~ chi-square(2)` and its `p.value`.

## References

Mardia KV (1976); Zar JH (1999) eq. 27.19.

## See also

[`circularSummary()`](https://x-biosignal.github.io/PhysioMoCap/reference/circularSummary.md)

## Examples

``` r
set.seed(3); th <- runif(60, 0, 360); y <- cos(th * pi / 180) + rnorm(60, 0, 0.3)
circularLinearCorrelation(th, y)$estimate            # strong association
#>        r 
#> 0.932514 
```
