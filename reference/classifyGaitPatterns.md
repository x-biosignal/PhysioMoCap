# Classify gait pathology patterns from a bundle of gait variables

Runs each applicable detector on the supplied gait-cycle waveforms and
returns a per-pattern flag and severity. A pattern is evaluated only
when its input variable is present in `variables`.

## Usage

``` r
classifyGaitPatterns(variables, params = list())
```

## Arguments

- variables:

  A named list of gait-cycle waveforms. Recognised names:
  `knee_flexion`, `ankle_power`, `foot_ml`, `pelvic_obliquity`.

- params:

  Optional named list of per-pattern argument lists forwarded to the
  individual detectors (e.g. `list(stiff_knee = list(threshold = 40))`).

## Value

A data frame (class `gait_pattern_classification`) with columns
`pattern`, `flagged`, `severity`, `metric`, `threshold`, one row per
evaluated pattern.

## See also

[`gaitPatternLibrary()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitPatternLibrary.md)

## Examples

``` r
vars <- list(knee_flexion = 60 * sin(seq(0, pi, length.out = 101)))
classifyGaitPatterns(vars)
#> Gait pathology classification:
#>   stiff_knee         normal (severity 0.06)
```
