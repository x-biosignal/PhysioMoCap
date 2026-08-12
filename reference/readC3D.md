# Read C3D Motion Capture File

Reads a C3D file containing 3D marker position data using the c3dr
package. C3D is a widely used binary format for storing biomechanical
motion capture data including point (marker) positions and optional
analog channel data (e.g., force plate signals).

## Usage

``` r
readC3D(path, include_analog = FALSE)
```

## Arguments

- path:

  Character string giving the path to the `.c3d` file.

- include_analog:

  Logical; if `TRUE`, analog data (e.g., force plate channels) is
  extracted and stored in `metadata(pe)$analog_data` as a data frame.
  Default is `FALSE`.

## Value

A `PhysioExperiment` object with three assays: `"position_x"`,
`"position_y"`, and `"position_z"`, each a matrix with rows as time
frames and columns as markers. If the C3D file contains residual data, a
`"quality"` assay is also included. Column metadata (`colData`) contains
`label` (marker names from POINT:LABELS), `type` (`"marker"`), and
`body_segment` (`NA`). Metadata includes `c3d_parameters`,
`source_file`, and a `time` vector computed from frame rate.

## References

C3D.org. "The C3D File Format." <https://www.c3d.org/>.

## See also

[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`readBVH()`](https://x-biosignal.github.io/PhysioMoCap/reference/readBVH.md),
[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)

## Examples

``` r
if (requireNamespace("c3dr", quietly = TRUE)) {
  c3d_file <- c3dr::c3d_example()
  pe <- readC3D(c3d_file)
  pe
}
#> class: PhysioExperiment
#> dim: 340 x 55 
#> assays(3): position_x, position_y, position_z
#> samplingRate: 200 Hz
#> channels(55): L_IAS, L_IPS, R_IPS, R_IAS, SNJ ...
#> colData names(3): label, type, body_segment
```
