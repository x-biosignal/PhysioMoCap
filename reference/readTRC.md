# Read OpenSim TRC File (.trc)

Reads marker trajectory data from an OpenSim TRC file. TRC files store
3D marker positions (X, Y, Z) in a specific header format that differs
from MOT/STO files.

## Usage

``` r
readTRC(path)
```

## Arguments

- path:

  Character string giving the path to the `.trc` file.

## Value

A `PhysioExperiment` object with three assays: `"position_x"`,
`"position_y"`, and `"position_z"`, each with columns named by marker.
Header metadata (DataRate, Units, etc.) is stored in `metadata()`.

## References

Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
Dynamic Simulations of Movement." IEEE Transactions on Biomedical
Engineering, 54(11), 1940-1950.

## See also

[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md),
[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)

## Examples

``` r
trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
if (nzchar(trc_file)) {
  pe <- readTRC(trc_file)
  pe
}
#> class: PhysioExperiment
#> dim: 5 x 2 
#> assays(3): position_x, position_y, position_z
#> samplingRate: 120 Hz
#> channels(2): RASI, LASI
#> colData names(2): label, type
```
