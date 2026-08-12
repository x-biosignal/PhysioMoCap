# Create an Event definition

Defines an event within a movement task that can be detected
automatically or specified manually.

## Usage

``` r
Event(
  name,
  label,
  detection_method = "threshold",
  detection_params = list(),
  typical_timing = NULL
)
```

## Arguments

- name:

  Short identifier for the event (e.g., "hs1", "to")

- label:

  Human-readable label (e.g., "Heel Strike", "Toe Off")

- detection_method:

  Method for automatic detection:

  - "threshold" - Signal crosses a threshold value

  - "peak" - Local maximum or minimum

  - "zero_crossing" - Signal crosses zero

  - "angle" - Specific angle value (for cyclic data)

  - "velocity_threshold" - Velocity exceeds threshold

  - "manual" - User-specified timing

- detection_params:

  List of parameters for detection method:

  - For "threshold": signal, threshold, direction ("rising"/"falling")

  - For "peak": signal, type ("max"/"min"), prominence

  - For "zero_crossing": signal, direction ("rising"/"falling"/"any")

  - For "angle": signal, value

- typical_timing:

  Expected timing as percentage of movement (0-100), used for validation
  and as fallback

## Value

An Event object (S3 class)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`Phase()`](https://x-biosignal.github.io/PhysioMoCap/reference/Phase.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)

## Examples

``` r
# Heel strike event detected when vertical GRF rises above 10N
hs <- Event("hs", "Heel Strike", "threshold",
            list(signal = "vGRF", threshold = 10, direction = "rising"),
            typical_timing = 0)

# Toe off event detected when vertical GRF falls below 10N
to <- Event("to", "Toe Off", "threshold",
            list(signal = "vGRF", threshold = 10, direction = "falling"),
            typical_timing = 60)

# Peak knee flexion
pk <- Event("peak_flex", "Peak Knee Flexion", "peak",
            list(signal = "knee_angle", type = "max"))
```
