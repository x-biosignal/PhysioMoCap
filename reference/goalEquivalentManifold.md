# Goal-Equivalent Manifold (GEM) decomposition for a scalar goal

The scalar-goal special case of UCM (Cusumano & Cesari 2006): given the
gradient of a scalar goal function, split the execution variability into
goal-equivalent (along the level set – does not change the goal) and
non-goal-equivalent (along the gradient – changes it), and report the
motor-equivalent ratio.

## Usage

``` r
goalEquivalentManifold(execution, goal_gradient = NULL, goal = NULL)
```

## Arguments

- execution:

  An `N x m` matrix of execution/body variables across trials.

- goal_gradient:

  Length-`m` gradient of the goal function at the mean (the direction in
  which the goal changes fastest). Provide this, or `goal`.

- goal:

  Optional scalar goal function `R^m -> R`; its gradient is computed
  numerically at the mean when `goal_gradient` is not given.

## Value

a `gem_result` list: `gev` (goal-equivalent variance, along the GEM),
`ngev` (non-goal-equivalent variance, along the gradient), `me_ratio`
(`gev / ngev`, \> 1 = variability channelled into the goal-irrelevant
direction), `log_me_ratio`.

## References

Cusumano JP, Cesari P (2006) Biol Cybern 94:367-379.

## See also

[`uncontrolledManifold()`](https://x-biosignal.github.io/PhysioMoCap/reference/uncontrolledManifold.md)

## Examples

``` r
set.seed(2)
x1 <- rnorm(200, 10, 3); x2 <- 20 - x1 + rnorm(200, 0, 0.4)  # x1+x2 ~ const
goalEquivalentManifold(cbind(x1, x2), goal_gradient = c(1, 1))$me_ratio
#> [1] 268.2205
```
