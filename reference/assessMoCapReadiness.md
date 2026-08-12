# Assess readiness of a MoCap dataset for downstream analysis

Performs a compact quality and metadata checklist so beginners can
quickly identify missing requirements before running kinematics or
kinetics.

## Usage

``` r
assessMoCapReadiness(
  pe,
  required_assays = c("position_x", "position_y", "position_z"),
  min_frames = 100,
  min_markers = 5,
  min_sampling_rate = 50,
  max_missing_rate = 0.05
)
```

## Arguments

- pe:

  A `PhysioExperiment` object.

- required_assays:

  Character vector of required assay names.

- min_frames:

  Minimum recommended number of frames.

- min_markers:

  Minimum recommended number of markers/channels.

- min_sampling_rate:

  Minimum recommended sampling rate (Hz).

- max_missing_rate:

  Maximum allowed missing-value rate per required assay.

## Value

An S3 object of class `"mocap_readiness"` with score, grade, checks, and
summary metrics.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`print.mocap_readiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.mocap_readiness.md)
for formatted display of readiness results,
[`quickStartMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/quickStartMoCap.md)
for complete getting-started workflow,
[`demoMoCapData()`](https://x-biosignal.github.io/PhysioMoCap/reference/demoMoCapData.md)
for generating demo data.

## Examples

``` r
demo <- demoMoCapData(seed = 1)
report <- assessMoCapReadiness(demo$mocap)
report
#> MoCap Readiness Report
#>   Score:100% (A+)
#>   Frames: 300 
#>   Markers: 8 
#>   Checks: 8 / 8 passed
```
