# Gait-ataxia composite from gait-variability sub-metrics

Aggregates the standard gait-ataxia sub-metrics (each higher = more
ataxic): the coefficients of variation of step width, stride length and
stride time (from
[`summarizeGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeGaitParameters.md),
the `cv` column, in per cent) and trunk sway (e.g. `cop_path_length`
from
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md),
or trunk-marker RMS).

## Usage

``` r
gaitAtaxiaIndex(
  step_width_cv = NA_real_,
  stride_length_cv = NA_real_,
  stride_time_cv = NA_real_,
  trunk_sway = NA_real_,
  reference = NULL,
  weights = NULL
)
```

## Arguments

- step_width_cv, stride_length_cv, stride_time_cv:

  Gait coefficients of variation (per cent); any may be `NA`.

- trunk_sway:

  Trunk-sway magnitude (higher = worse); optional.

- reference, weights:

  As in
  [`limbAtaxiaIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/limbAtaxiaIndex.md).

## Value

An S3 `gait_ataxia` list: `metrics`, per-metric `z`, and `composite`.

## See also

[`summarizeGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeGaitParameters.md),
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md),
[`limbAtaxiaIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/limbAtaxiaIndex.md)

## Examples

``` r
gaitAtaxiaIndex(step_width_cv = 28, stride_length_cv = 9, stride_time_cv = 6)
#> Gait-ataxia sub-metrics (higher = more ataxic):
#>   step_width_cv    28
#>   stride_length_cv 9
#>   stride_time_cv   6
#>   composite z      : NA (no reference supplied)
```
