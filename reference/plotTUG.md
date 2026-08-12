# Plot an instrumented TUG timeline

Plots the trunk yaw angular velocity with the detected turns shaded and
the sit-to-stand / turn-to-sit transitions marked.

## Usage

``` r
plotTUG(report, title = "Instrumented TUG")
```

## Arguments

- report:

  An `itug_report` from
  [`instrumentedTUG()`](https://x-biosignal.github.io/PhysioMoCap/reference/instrumentedTUG.md).

- title:

  Plot title.

## Value

A `ggplot` object.

## See also

[`instrumentedTUG()`](https://x-biosignal.github.io/PhysioMoCap/reference/instrumentedTUG.md)
