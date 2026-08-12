# Gait Profile Score (overall RMS deviation from the norm)

The Gait Profile Score (Baker et al. 2009) summarises overall gait
deviation as the root-mean-square of the Gait Variable Scores across all
kinematic variables (degrees). It is always non-negative and is zero
when the subject equals the normative mean.

## Usage

``` r
gaitProfileScore(kinematics, norm = NULL)
```

## Arguments

- kinematics:

  Subject kinematics: a numeric matrix with one row per kinematic
  variable (row names matching `norm$variables`) and one column per
  gait-cycle point, or a named list of per-variable curves. Curves are
  time-normalised to the norm's cycle length via
  [`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md).

- norm:

  A `gait_norm` normative reference (from
  [`PhysioGaitNorm::loadGaitNorm()`](https://x-biosignal.github.io/PhysioGaitNorm//reference/loadGaitNorm.html));
  if `NULL`, the default reference is loaded from PhysioGaitNorm.

## Value

A single non-negative numeric (degrees).

## References

Baker R, et al. (2009). Gait & Posture 30(3):265-269.

## See also

[`gaitVariableScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitVariableScore.md),
[`movementAnalysisProfile()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementAnalysisProfile.md)

## Examples

``` r
norm <- list(variables = c("a", "b"),
             mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
             cycle_length = 51)
gaitProfileScore(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)), norm)
#> [1] 1
```
