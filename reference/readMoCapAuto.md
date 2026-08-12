# Read motion-capture files with automatic format detection

Chooses a reader based on file extension and returns a
`PhysioExperiment`. This is designed for first-time users who want one
entry point for common MoCap formats.

## Usage

``` r
readMoCapAuto(
  path,
  format = c("auto", "csv", "c3d", "trc", "bvh", "amc"),
  sampling_rate = NULL,
  sep = ",",
  header_rows = 1L,
  skip = 0L,
  include_analog = FALSE,
  asf = NULL,
  fps = 120
)
```

## Arguments

- path:

  Path to a motion-capture file.

- format:

  Reader format. `"auto"` detects from extension (`.c3d`, `.trc`,
  `.csv`, `.tsv`, `.bvh`, `.amc`).

- sampling_rate:

  Sampling rate for CSV files when not inferable.

- sep:

  Delimiter used for CSV/TSV files.

- header_rows:

  Number of header rows for CSV/TSV.

- skip:

  Number of lines to skip before data for CSV/TSV.

- include_analog:

  Logical; passed to
  [`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md).

- asf:

  Optional ASF skeleton for AMC files. Either an `ASFSkeleton` object or
  a path to an `.asf` file.

- fps:

  Frame rate for AMC files.

## Value

A `PhysioExperiment` object.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md)
for CSV/TSV motion capture data,
[`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)
and
[`readAMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readAMC.md)
for Acclaim skeleton and motion files,
[`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
for data quality assessment.

## Examples

``` r
trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
if (nzchar(trc_file)) {
  pe <- readMoCapAuto(trc_file)
  pe
}
#> class: PhysioExperiment
#> dim: 5 x 2 
#> assays(3): position_x, position_y, position_z
#> samplingRate: 120 Hz
#> channels(2): RASI, LASI
#> colData names(2): label, type
```
