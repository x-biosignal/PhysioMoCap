# Write a C3D Motion Capture File

Writes 3D marker trajectories (and optional analog channels) from a
`PhysioExperiment` to a binary C3D file via the c3dr package. This is
the inverse of
[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md):
a `readC3D() -> writeC3D() -> readC3D()` round-trip reproduces the
marker coordinates (within 32-bit float precision) and preserves the
point/analog sampling-rate ratio.

## Usage

``` r
writeC3D(x, path, include_analog = TRUE)
```

## Arguments

- x:

  A `PhysioExperiment` with `"position_x"`, `"position_y"`, and
  `"position_z"` assays (as produced by
  [`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)
  or
  [`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)),
  or a `MultiRatePhysioExperiment` whose marker stream carries those
  assays.

- path:

  Character string giving the output `.c3d` path.

- include_analog:

  Logical; if `TRUE` (default) and the object carries analog data (in
  `metadata(x)$analog_data`, or as an `"analog"` stream of a
  `MultiRatePhysioExperiment`), that data is written as C3D analog
  channels. If `FALSE`, a marker-only C3D file is written.

## Value

The output `path`, invisibly.

## Details

The point (marker) rate is taken from `samplingRate(x)`. When analog
data is written, the analog rate and the integer point/analog ratio
(`ANALOG:RATE / POINT:RATE`, i.e. analog subframes per point frame) are
derived from the analog block so the ratio round-trips exactly. Force
platform metadata is not written (the marker and analog signals are
preserved; force-plate corner/calibration parameters are dropped).

## References

C3D.org. "The C3D File Format." <https://www.c3d.org/>.

## See also

[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md),
[`writeTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeTRC.md),
[`writeMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeMOT.md)

## Examples

``` r
if (requireNamespace("c3dr", quietly = TRUE)) {
  pe <- readC3D(c3dr::c3d_example(), include_analog = TRUE)
  out <- tempfile(fileext = ".c3d")
  writeC3D(pe, out)
  pe2 <- readC3D(out)
}
```
