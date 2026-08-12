# Create a Phase definition

Defines a phase within a movement task, bounded by start and end events.

## Usage

``` r
Phase(name, label, start_event, end_event, color = NULL, subphases = list())
```

## Arguments

- name:

  Short identifier for the phase (e.g., "stance", "swing")

- label:

  Human-readable label (e.g., "Stance Phase")

- start_event:

  Name of the event marking phase start

- end_event:

  Name of the event marking phase end

- color:

  Optional color for visualization (hex code)

- subphases:

  Optional list of Phase objects for nested phases

## Value

A Phase object (S3 class)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`Event()`](https://x-biosignal.github.io/PhysioMoCap/reference/Event.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)

## Examples

``` r
# Simple phase definition
stance <- Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8")

# Phase with subphases
stance <- Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8",
                subphases = list(
                  Phase("loading", "Loading Response", "hs1", "ff"),
                  Phase("midstance", "Midstance", "ff", "ho"),
                  Phase("propulsion", "Propulsion", "ho", "to")
                ))
```
