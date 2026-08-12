# Analyze force-plate signals from a PhysioExperiment object

Convenience wrapper for
[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
when force and moment components are stored in PhysioExperiment assays.

## Usage

``` r
analyzeForcePlatePE(
  pe,
  force_assay = "grf",
  moment_assay = NULL,
  plate_index = 1L,
  sampling_rate = NULL,
  ...
)
```

## Arguments

- pe:

  A PhysioExperiment object.

- force_assay:

  Assay name containing force data with 3 columns (X, Y, Z). If not
  present, the function tries `force_x`, `force_y`, and `force_z`
  assays.

- moment_assay:

  Optional assay name containing moments with 3 columns. If not present,
  the function tries `moment_x`, `moment_y`, and `moment_z`.

- plate_index:

  Which plate to analyze when components are provided as separate assays
  with multiple force plates. Accepts:

  - numeric scalar (specific plate),

  - `"auto"` (select plate with largest vertical-force impulse),

  - `"all"` (analyze all plates and return a multi-plate result).

- sampling_rate:

  Optional sampling rate in Hz. If `NULL`, uses `samplingRate(pe)`.

- ...:

  Additional arguments passed to
  [`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md).

## Value

A `forceplate_analysis` object (single plate) or
`forceplate_analysis_multi` (when `plate_index = "all"`).

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for matrix-based force plate analysis,
[`print.forceplate_analysis()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.forceplate_analysis.md)
for displaying results.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readC3D("trial.c3d", include_analog = TRUE)
out <- analyzeForcePlatePE(pe)
} # }
```
