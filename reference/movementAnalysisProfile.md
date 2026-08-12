# Movement Analysis Profile (GVS per variable plus the GPS)

The Movement Analysis Profile (Baker et al. 2009) collects the
per-variable Gait Variable Scores together with the overall Gait Profile
Score.

## Usage

``` r
movementAnalysisProfile(kinematics, norm = NULL)
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

A `movement_analysis_profile` object: a list with `gvs` (named numeric
vector), `gps` (numeric), `variables`, and `cycle_length`.

## References

Baker R, et al. (2009). Gait & Posture 30(3):265-269.

## See also

[`gaitProfileScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitProfileScore.md),
[`gaitVariableScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitVariableScore.md),
[`plotMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotMAP.md)

## Examples

``` r
norm <- list(variables = c("a", "b"),
             mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
             cycle_length = 51)
movementAnalysisProfile(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)),
                        norm)
#> <movement_analysis_profile>
#>   GPS (overall): 1.00 deg
#>   GVS per variable (deg):
#>     a                    1.00
#>     b                    1.00
```
