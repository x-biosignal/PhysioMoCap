# Manually specify event times

Create a detected_events object from manually specified times or
indices.

## Usage

``` r
manualEvents(
  schema,
  times = NULL,
  indices = NULL,
  sampling_rate = NULL,
  n_samples
)
```

## Arguments

- schema:

  TaskSchema object

- times:

  Named numeric vector of event times in seconds

- indices:

  Named integer vector of event indices

- sampling_rate:

  Sampling rate (required if using times)

- n_samples:

  Total number of samples (required)

## Value

A detected_events data.frame

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md)

## Examples

``` r
events <- manualEvents(
  schema_gait,
  times = c(hs1 = 0, to = 0.6, hs2 = 1.0),
  sampling_rate = 1000,
  n_samples = 1000
)
```
