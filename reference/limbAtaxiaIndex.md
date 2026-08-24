# Limb-ataxia composite from reaching sub-metrics

Aggregates the standard limb-ataxia sub-metrics, each oriented so that a
higher value means more ataxic movement. Supply them from the existing
primitives: `dysmetria` from
[`endpointError()`](https://x-biosignal.github.io/PhysioMoCap/reference/endpointError.md)
(`absolute_error` or the magnitude of `constant_error`), `decomposition`
from
[`movementUnits()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementUnits.md)
(the submovement count), `smoothness` as a jerk/roughness score where
higher is worse (e.g. `-sparc` from
[`sparc()`](https://x-biosignal.github.io/PhysioMoCap/reference/sparc.md),
since SPARC is more negative for less smooth movement, or `ldlj`
magnitude), and `irregularity` from
[`pathStraightness()`](https://x-biosignal.github.io/PhysioMoCap/reference/pathStraightness.md)
(`index_of_curvature`).

## Usage

``` r
limbAtaxiaIndex(
  dysmetria = NA_real_,
  decomposition = NA_real_,
  smoothness = NA_real_,
  irregularity = NA_real_,
  reference = NULL,
  weights = NULL
)
```

## Arguments

- dysmetria, decomposition, smoothness, irregularity:

  Numeric sub-metrics (higher = more ataxic); any may be `NA` to omit
  it.

- reference:

  Optional data.frame of the same-named columns measured in a healthy
  reference sample; when given, each sub-metric is z-standardised
  against it and averaged into `composite`. Without a reference the
  composite is `NA` and only the sub-metrics are returned.

- weights:

  Optional named weights for the composite (default equal).

## Value

An S3 `limb_ataxia` list: `metrics`, per-metric `z`, and `composite`.

## See also

[`pathStraightness()`](https://x-biosignal.github.io/PhysioMoCap/reference/pathStraightness.md),
[`reachingKinematics()`](https://x-biosignal.github.io/PhysioMoCap/reference/reachingKinematics.md),
[`gaitAtaxiaIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitAtaxiaIndex.md)

## Examples

``` r
limbAtaxiaIndex(dysmetria = 3.2, decomposition = 4, smoothness = 5.1,
                irregularity = 1.4)
#> Limb-ataxia sub-metrics (higher = more ataxic):
#>   dysmetria      3.2
#>   decomposition  4
#>   smoothness     5.1
#>   irregularity   1.4
#>   composite z    : NA (no reference supplied)
```
