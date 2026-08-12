# Detect events in movement data

Automatically detects events defined in a TaskSchema based on signal
data.

## Usage

``` r
detectEvents(
  x,
  schema,
  signals = NULL,
  method = c("auto", "manual", "hybrid", "zeni"),
  sampling_rate = NULL,
  ...
)
```

## Arguments

- x:

  PhysioExperiment object or matrix (time x channels)

- schema:

  TaskSchema object defining events to detect

- signals:

  Named list of signal vectors for detection. If NULL and x is a
  PhysioExperiment, signals are extracted from column names. If x is a
  matrix with named columns, signals are auto-created from those names;
  otherwise provide `signals` explicitly.

- method:

  Detection approach:

  - "auto" - Automatic detection using schema definitions

  - "manual" - Use typical_timing from schema as event times

  - "hybrid" - Try auto first, fall back to typical_timing if failed

- sampling_rate:

  Sampling rate in Hz. Required if x is a matrix.

- ...:

  Additional arguments passed to detection methods

## Value

A data.frame with columns:

- event - Event name

- label - Human-readable label

- index - Sample index of event

- time - Time in seconds

- percent - Percent of movement (if applicable)

- method - Detection method used

- confidence - Detection confidence (0-1)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`manualEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/manualEvents.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md)

## Examples

``` r
# Create synthetic gait data
set.seed(123)
n <- 1000
t <- seq(0, 1, length.out = n)
vGRF <- c(rep(0, 100), sin(seq(0, pi, length.out = 500)) * 800, rep(0, 400))
vGRF <- vGRF + rnorm(n, 0, 10)

signals <- list(vGRF = vGRF)
events <- detectEvents(as.matrix(vGRF), schema_gait,
                       signals = signals, sampling_rate = 1000)
```
