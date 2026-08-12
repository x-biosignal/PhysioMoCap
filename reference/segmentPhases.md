# Segment data into phases

Divides movement data into phases based on detected events and schema
definition.

## Usage

``` r
segmentPhases(x, events, schema, include_subphases = TRUE)
```

## Arguments

- x:

  PhysioExperiment object or matrix (time x channels)

- events:

  A detected_events data.frame from detectEvents()

- schema:

  TaskSchema object defining phase structure

- include_subphases:

  Whether to include subphases in output

## Value

A segmented_phases object (list) containing:

- phases - List of phase data

- metadata - Phase timing information

- schema - Original schema

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md),
[`extractPhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractPhase.md),
[`phaseTiming()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseTiming.md),
[`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md)

## Examples

``` r
# Assuming events have been detected
# phases <- segmentPhases(data, events, schema_gait)
```
