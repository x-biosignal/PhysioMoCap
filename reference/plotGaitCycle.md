# Plot gait cycle normalized waveforms

Plots waveforms normalized to gait cycle (0-100%) with options for
displaying multiple trials, mean, and variability bands.

## Usage

``` r
plotGaitCycle(
  x,
  events = NULL,
  normalize_to = 101,
  show_events = TRUE,
  show_mean = TRUE,
  show_sd = TRUE,
  show_individual = TRUE,
  event_labels = c(HS = 0, TO = 60, HS = 100),
  title = "Gait Cycle",
  ylab = "Value"
)
```

## Arguments

- x:

  A PhysioExperiment, matrix, or list of matrices.

- events:

  Optional data.frame with gait events (heel strike, toe off).

- normalize_to:

  Length to normalize (default: 101 for 0-100%).

- show_events:

  Logical; show vertical lines at gait events.

- show_mean:

  Logical; show mean waveform.

- show_sd:

  Logical; show SD bands.

- show_individual:

  Logical; show individual trials.

- event_labels:

  Labels for gait events.

- title:

  Plot title.

- ylab:

  Y-axis label.

## Value

A ggplot object.

## References

Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis."
Springer.

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`plotWaveformComparison()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotWaveformComparison.md)
for multi-group comparisons,
[`plotSpaghetti()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSpaghetti.md)
for individual waveform overlays,
[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
for computing gait metrics.

## Examples

``` r
# Normalize and plot knee angle across gait cycle
set.seed(123)
data <- sapply(1:10, function(i) {
  n <- sample(90:110, 1)  # Variable cycle length
  sin(seq(0, 2*pi, length.out = n)) * 60 + rnorm(n, 0, 3)
})

plotGaitCycle(data, show_mean = TRUE, show_sd = TRUE,
              ylab = "Knee Flexion (deg)")
```
