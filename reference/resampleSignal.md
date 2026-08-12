# Resample signal assays to a new sampling rate

Resamples all (or selected) numeric assays of a PhysioExperiment object
to a new target sampling rate. Both upsampling and downsampling are
supported.

## Usage

``` r
resampleSignal(
  pe,
  target_rate,
  method = c("linear", "spline"),
  assay_names = NULL
)
```

## Arguments

- pe:

  A PhysioExperiment object.

- target_rate:

  Target sampling rate in Hz.

- method:

  Interpolation method: "linear" (default) or "spline".

- assay_names:

  Character vector of assay names to resample. If NULL (default), all
  numeric assays are resampled.

## Value

A new PhysioExperiment with resampled assays, updated `samplingRate`,
and updated `metadata$time` vector.

## References

Oppenheim AV, Willsky AS, Nawab SH (1997). "Signals and Systems." 2nd
ed. Prentice Hall.

## See also

[`resampleVector()`](https://x-biosignal.github.io/PhysioMoCap/reference/resampleVector.md)
for resampling individual numeric vectors,
[`synchronizeSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/synchronizeSignals.md)
for synchronizing multiple experiments.

## Examples

``` r
pe <- PhysioCore::PhysioExperiment(
  assays = S4Vectors::SimpleList(
    position_x = matrix(sin(seq(0, 2 * pi, length.out = 100)), ncol = 1)
  ),
  colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
  samplingRate = 100
)
pe2 <- resampleSignal(pe, target_rate = 200)
PhysioCore::samplingRate(pe2)  # 200
#> [1] 200
```
