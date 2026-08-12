# Registry of supported gait pathology patterns

Documents the gait deviation patterns detected by this package, their
input variable, detector, threshold and clinical reference.

## Usage

``` r
gaitPatternLibrary()
```

## Value

A data frame (class `gait_pattern_library`).

## See also

[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md),
[`detectStiffKnee()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStiffKnee.md),
[`detectPushOffDeficit()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectPushOffDeficit.md),
[`detectCircumduction()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectCircumduction.md),
[`detectTrendelenburg()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectTrendelenburg.md)

## Examples

``` r
gaitPatternLibrary()
#> Gait pattern library (4 patterns):
#>   - stiff_knee         [knee_flexion] Reduced or delayed peak swing knee flexion
#>   - push_off_deficit   [ankle_power] Reduced ankle plantarflexor push-off power
#>   - circumduction      [foot_ml] Lateral swing trajectory of a functionally long limb
#>   - trendelenburg      [pelvic_obliquity] Contralateral pelvic drop from hip-abductor weakness
```
