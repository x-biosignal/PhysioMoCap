# Create a Task Schema

Defines a complete movement task schema including events, phases,
normalization method, metrics, and visualization defaults.

## Usage

``` r
TaskSchema(
  task_type,
  task_label = task_type,
  events = list(),
  phases = list(),
  normalization = c("cycle", "phase", "landmark", "dtw", "absolute"),
  norm_length = 101L,
  metrics = character(),
  vis_defaults = list()
)
```

## Arguments

- task_type:

  Short identifier for the task type (e.g., "gait", "jump")

- task_label:

  Human-readable label (e.g., "Gait Cycle", "Vertical Jump")

- events:

  List of Event objects defining key timepoints

- phases:

  List of Phase objects defining movement phases

- normalization:

  Normalization method:

  - "cycle" - Normalize entire movement to 0-100%

  - "phase" - Normalize each phase independently to 0-100%

  - "landmark" - Align to a specific event

  - "dtw" - Dynamic time warping alignment

  - "absolute" - Keep original time (no normalization)

- norm_length:

  Target length after normalization (default 101 for 0-100%)

- metrics:

  Character vector of recommended metrics for this task

- vis_defaults:

  List of default visualization parameters:

  - xlab - X-axis label

  - ylab - Y-axis label

  - show_phases - Whether to show phase regions

  - show_events - Whether to show event markers

  - phase_alpha - Transparency for phase shading

  - landmark_event - Event to align to (for landmark normalization)

## Value

A TaskSchema object (S3 class)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`Event()`](https://x-biosignal.github.io/PhysioMoCap/reference/Event.md),
[`Phase()`](https://x-biosignal.github.io/PhysioMoCap/reference/Phase.md),
[`getSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/getSchema.md),
[`validateSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateSchema.md)

## Examples

``` r
# Simple task schema
my_task <- TaskSchema(
  task_type = "simple",
  task_label = "Simple Movement",
  events = list(
    Event("start", "Start", "threshold",
          list(signal = "velocity", threshold = 0.1, direction = "rising")),
    Event("end", "End", "threshold",
          list(signal = "velocity", threshold = 0.1, direction = "falling"))
  ),
  phases = list(
    Phase("main", "Main Phase", "start", "end")
  ),
  normalization = "cycle"
)
```
