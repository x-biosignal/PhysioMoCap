# Gait Variable Score (per-variable RMS deviation from the norm)

The Gait Variable Score (Baker et al. 2009) is the root-mean-square
difference, over the gait cycle, between a subject's kinematic curve and
the normative mean, computed separately for each kinematic variable
(degrees).

## Usage

``` r
gaitVariableScore(kinematics, norm = NULL)
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

A named numeric vector of GVS values (degrees), one per variable.

## References

Baker R, et al. (2009). Gait & Posture 30(3):265-269.

## See also

[`gaitProfileScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitProfileScore.md),
[`movementAnalysisProfile()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementAnalysisProfile.md)

## Examples

``` r
norm <- list(variables = c("a", "b"),
             mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
             cycle_length = 51)
gaitVariableScore(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)), norm)
#> a b 
#> 1 1 
```
