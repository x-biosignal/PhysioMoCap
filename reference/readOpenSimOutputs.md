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

  One of `"auto"`, `"mot"`, `"sto"`, `"trc"`.

## Value

Named list of PhysioExperiment objects.

## See also

[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md),
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
