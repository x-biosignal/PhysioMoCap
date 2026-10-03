# Read OpenSim Output Files

Reads one or more OpenSim output files and returns PhysioExperiment
objects.

## Usage

``` r
readOpenSimOutputs(files, format = c("auto", "mot", "sto", "trc"))
```

## Arguments

- files:

  Character vector of file paths.

- format:

  One of `\"auto\"`, `\"mot\"`, `\"sto\"`, `\"trc\"`.

## Value

Named list of PhysioExperiment objects.

## See also

[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md),
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)

## Examples

``` r
f <- system.file("testdata", "sample.mot", package = "PhysioMoCap")
if (nzchar(f)) {
  out <- readOpenSimOutputs(f)
  out
}
#> $sample
#> class: PhysioExperiment
#> dim: 5 x 3 
#> assays(1): raw
#> samplingRate: 100 Hz
#> channels(3): hip_flexion_r, knee_angle_r, ankle_angle_r
#> colData names(2): label, type
#> 
```
