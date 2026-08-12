# Normalize movement data

Normalizes movement data using various methods appropriate for different
task types.

## Usage

``` r
normalizeMovement(
  x,
  method = c("cycle", "phase", "landmark", "dtw", "absolute"),
  norm_length = 101L,
  schema = NULL,
  events = NULL,
  reference = NULL,
  ...
)
```

## Arguments

- x:

  Data to normalize:

  - PhysioExperiment object

  - Matrix (time x channels)

  - segmented_phases object

  - List of matrices (multiple trials)

- method:

  Normalization method:

  - "cycle" - Normalize entire movement to fixed length (0-100%)

  - "phase" - Normalize each phase independently

  - "landmark" - Align to a specific event

  - "dtw" - Dynamic time warping alignment

  - "absolute" - Keep original time (no normalization)

- norm_length:

  Target length after normalization (default 101 for 0-100%)

- schema:

  Optional TaskSchema for context

- events:

  Optional detected_events for landmark alignment

- reference:

  Reference trial for DTW (default: mean of all trials)

- ...:

  Additional arguments passed to specific methods

## Value

Normalized data in the same format as input (or matrix for
segmented_phases)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`batchNormalize()`](https://x-biosignal.github.io/PhysioMoCap/reference/batchNormalize.md),
[`normalizedTimeAxis()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizedTimeAxis.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)

## Examples

``` r
# Normalize a matrix to 101 points
data <- matrix(rnorm(500), nrow = 500, ncol = 3)
normalized <- normalizeMovement(data, method = "cycle", norm_length = 101)
```
