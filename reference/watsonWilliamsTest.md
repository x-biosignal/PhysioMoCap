# Watson-Williams test for equal mean directions

The circular analogue of a one-way ANOVA: tests whether two or more
groups of angles share a common mean direction (assuming von Mises data
of similar concentration). Use it to compare, e.g., coupling angles
between limbs, speeds or groups.

## Usage

``` r
watsonWilliamsTest(angles, group = NULL, units = c("degrees", "radians"))
```

## Arguments

- angles:

  Numeric vector of angles, or a list of per-group angle vectors.

- group:

  Grouping factor (length `length(angles)`); required when `angles` is a
  single vector, ignored when `angles` is a list.

- units:

  `"degrees"` (default) or `"radians"`.

## Value

an `htest`: `F` statistic (concentration-corrected), df and `p.value`.
Warns when the pooled concentration is low (`rbar < 0.45`), where the
test is unreliable.

## References

Watson GS, Williams EJ (1956); Zar JH (1999) eq. 27.9.

## See also

[`rayleighTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/rayleighTest.md)

## Examples

``` r
set.seed(2)
g1 <- rnorm(25, 20, 10); g2 <- rnorm(25, 60, 10)
watsonWilliamsTest(list(g1, g2))$p.value              # differ -> small
#> [1] 9.183644e-15
```
