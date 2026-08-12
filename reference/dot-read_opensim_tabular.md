# Internal parser for tab-separated OpenSim files (MOT/STO)

Both MOT and STO files share the same general structure: a header block
with key=value metadata lines ending at "endheader", followed by a
tab-separated data table whose first column is time.

## Usage

``` r
.read_opensim_tabular(path, format = c("mot", "sto"))
```

## Arguments

- path:

  File path.

- format:

  Character, either `"mot"` or `"sto"`.

## Value

A PhysioExperiment object.
