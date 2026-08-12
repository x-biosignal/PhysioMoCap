# Read OpenSim Storage File (.sto)

Reads an OpenSim storage file containing forces, moments, or other
computed quantities. STO files share the same tab-separated format as
MOT files with a header block ending in "endheader".

## Usage

``` r
readSTO(path)
```

## Arguments

- path:

  Character string giving the path to the `.sto` file.

## Value

A `PhysioExperiment` object with the data stored in the `"raw"` assay.
The first column (time) is used to compute the sampling rate. Header
metadata is stored in `metadata()`.

## References

Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
Dynamic Simulations of Movement." IEEE Transactions on Biomedical
Engineering, 54(11), 1940-1950.

## See also

[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)

## Examples

``` r
sto_file <- system.file("testdata", "sample.sto", package = "PhysioMoCap")
if (nzchar(sto_file)) {
  pe <- readSTO(sto_file)
  pe
}
#> class: PhysioExperiment
#> dim: 5 x 2 
#> assays(1): raw
#> samplingRate: 100 Hz
#> channels(2): ground_force_vx, ground_force_vy
#> colData names(2): label, type
```
