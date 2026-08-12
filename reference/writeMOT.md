# Write an OpenSim Motion File (.mot)

Writes tabular time-series data (joint angles, kinematics, ...) from a
`PhysioExperiment` to an OpenSim `.mot` file. This is the inverse of
[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md):
a `readMOT() -> writeMOT() -> readMOT()` round-trip reproduces every
numeric column exactly and the derived sampling rate.

## Usage

``` r
writeMOT(x, path)
```

## Arguments

- x:

  A `PhysioExperiment` whose first assay holds the data columns.

- path:

  Character string giving the output `.mot` path.

## Value

The output `path`, invisibly.

## Details

The time column is taken from `metadata(x)$time` when present, otherwise
it is reconstructed from `samplingRate(x)`. The `inDegrees` header flag
is preserved from `metadata(x)$inDegrees` (default `"yes"`).

## See also

[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`writeTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeTRC.md)

## Examples

``` r
mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
if (nzchar(mot_file)) {
  pe <- readMOT(mot_file)
  out <- tempfile(fileext = ".mot")
  writeMOT(pe, out)
}
```
