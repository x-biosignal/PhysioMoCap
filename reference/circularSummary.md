# Circular mean direction and spread

The mean direction of a set of angles and its circular spread, computed
via the resultant vector (so the wrap-around at 0/360 is handled
correctly).

## Usage

``` r
circularSummary(angles, units = c("degrees", "radians"))
```

## Arguments

- angles:

  Numeric vector of angles.

- units:

  `"degrees"` (default) or `"radians"`.

## Value

a `circular_summary` list: `mean` (mean direction), `R` (resultant
length), `rbar` (mean resultant length in \[0,1\]), `variance`
(`1 - rbar`), `sd` (circular SD), `kappa` (von Mises concentration), all
in the input units where applicable.

## References

Zar JH (1999) Biostatistical Analysis, ch. 26-27.

## See also

[`rayleighTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/rayleighTest.md),
[`circularLinearCorrelation()`](https://x-biosignal.github.io/PhysioMoCap/reference/circularLinearCorrelation.md)

## Examples

``` r
circularSummary(c(10, 20, 350, 355))$mean        # ~ 0, not ~180
#> [1] 3.733701
```
