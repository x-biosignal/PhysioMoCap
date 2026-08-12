# Plot normalized movement cycle

Creates a waveform plot with automatic phase and event annotations based
on the TaskSchema. This is a generalized version of plotGaitCycle.

## Usage

``` r
plotCycle(
  x,
  schema = NULL,
  events = NULL,
  channel = 1L,
  show_mean = TRUE,
  show_sd = TRUE,
  show_ci = FALSE,
  ci = 0.95,
  show_individual = FALSE,
  show_events = NULL,
  show_phases = NULL,
  time_axis = NULL,
  xlab = NULL,
  ylab = "Value",
  title = NULL,
  colors = NULL,
  ...
)
```

## Arguments

- x:

  Normalized data (matrix, PhysioExperiment, or 3D array)

- schema:

  TaskSchema object for formatting and annotations

- events:

  Optional detected_events for event markers

- channel:

  Channel index or name to plot (for multi-channel data)

- show_mean:

  Show mean line

- show_sd:

  Show standard deviation band

- show_ci:

  Show confidence interval band

- ci:

  Confidence level (default 0.95)

- show_individual:

  Show individual trials

- show_events:

  Show event markers

- show_phases:

  Show phase regions

- time_axis:

  Custom time axis values

- xlab:

  X-axis label (default from schema)

- ylab:

  Y-axis label

- title:

  Plot title

- colors:

  Named vector of colors for phases

- ...:

  Additional arguments passed to ggplot

## Value

A ggplot object

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

## See also

[`plotGroupComparison()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGroupComparison.md)
for multi-group comparisons,
[`plotMultiPanel()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotMultiPanel.md)
for multi-channel cycle visualization,
[`plotPhaseDurations()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPhaseDurations.md)
for phase duration bar charts.

## Examples

``` r
# Basic usage with schema
data <- matrix(rnorm(101 * 10), nrow = 101)
p <- plotCycle(data, schema = schema_gait)

# With events
events <- manualEvents(schema_gait, c(hs1 = 0, to = 0.6, hs2 = 1.0),
                       sampling_rate = 100, n_samples = 101)
p <- plotCycle(data, schema = schema_gait, events = events)
```
