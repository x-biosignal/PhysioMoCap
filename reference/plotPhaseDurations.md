# Plot phase duration comparison

Visualizes phase durations across conditions or groups.

## Usage

``` r
plotPhaseDurations(
  phases_list,
  labels = NULL,
  unit = c("percent", "seconds"),
  show_values = TRUE,
  title = "Phase Durations",
  ...
)
```

## Arguments

- phases_list:

  List of segmented_phases objects or timing data.frames

- labels:

  Labels for each entry

- unit:

  "percent" or "seconds"

- show_values:

  Show duration values on bars

- title:

  Plot title

- ...:

  Additional arguments

## Value

A ggplot object

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

## See also

[`plotCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotCycle.md)
for cycle-normalized waveform visualization,
[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for computing gait phase parameters.
