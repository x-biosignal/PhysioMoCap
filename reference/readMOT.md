# Read OpenSim Motion File (.mot)

Reads an OpenSim motion file containing joint angles, kinematics, or
other time-series data. MOT files use a tab-separated format with a
header block ending in "endheader".

## Usage

``` r
readMOT(path)
```

## Arguments

- path:

  Character string giving the path to the `.mot` file.

## Value

A `PhysioExperiment` object with the data stored in the `"raw"` assay.
The first column (time) is used to compute the sampling rate. Header
metadata such as `inDegrees` is stored in `metadata()`.

## References

Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
Dynamic Simulations of Movement." IEEE Transactions on Biomedical
Engineering, 54(11), 1940-1950.

## See also

[`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md),
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)

## Examples

``` r
mot_file <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
if (nzchar(mot_file)) {
  pe <- readMOT(mot_file)
  pe
}
#> class: PhysioExperiment
#> dim: 5 x 3 
#> assays(1): raw
#> samplingRate: 100 Hz
#> channels(3): hip_flexion_r, knee_angle_r, ankle_angle_r
#> colData names(2): label, type
```
