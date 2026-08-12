# Write an OpenSim TRC File (.trc)

Writes 3D marker trajectories from a `PhysioExperiment` to an OpenSim
`.trc` file. This is the inverse of
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md):
a `readTRC() -> writeTRC() -> readTRC()` round-trip reproduces the
marker coordinates exactly and the `DataRate` header field.

## Usage

``` r
writeTRC(x, path)
```

## Arguments

- x:

  A `PhysioExperiment` with `"position_x"`, `"position_y"`, and
  `"position_z"` assays (as produced by
  [`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
  or
  [`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)).

- path:

  Character string giving the output `.trc` path.

## Value

The output `path`, invisibly.

## Details

Marker labels, units (`metadata(x)$Units`, default `"mm"`), frame rate,
and the time column (`metadata(x)$time`, else derived from
`samplingRate(x)`) are preserved on write.

## See also

[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`writeMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeMOT.md),
[`writeC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeC3D.md)

## Examples

``` r
trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
if (nzchar(trc_file)) {
  pe <- readTRC(trc_file)
  out <- tempfile(fileext = ".trc")
  writeTRC(pe, out)
}
```
