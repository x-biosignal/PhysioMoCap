# Plot effect size forest plot

Creates a forest plot displaying effect sizes with confidence intervals,
commonly used for meta-analysis style visualization of multiple
comparisons.

## Usage

``` r
plotEffectSizeForest(
  effects,
  ci_lower,
  ci_upper,
  labels = NULL,
  null_value = 0,
  sort_by = c("none", "effect", "name"),
  title = "Effect Sizes"
)
```

## Arguments

- effects:

  Named vector or data.frame of effect sizes.

- ci_lower:

  Lower confidence interval bounds.

- ci_upper:

  Upper confidence interval bounds.

- labels:

  Labels for each effect (uses names if not provided).

- null_value:

  Reference line value (default: 0).

- sort_by:

  How to sort: "none", "effect", "name".

- title:

  Plot title.

## Value

A ggplot object.

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

## See also

[`cohensD()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/cohensD.html)
for computing Cohen's d effect sizes,
[`etaSquared()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/etaSquared.html)
for computing eta-squared effect sizes,
[`plotCorrelationMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotCorrelationMatrix.md)
for correlation heatmaps.

## Examples

``` r
# Forest plot of effect sizes across joints
effects <- c(Hip = 0.8, Knee = 1.2, Ankle = 0.3)
ci_lower <- c(0.4, 0.8, -0.1)
ci_upper <- c(1.2, 1.6, 0.7)

plotEffectSizeForest(effects, ci_lower, ci_upper)
```
