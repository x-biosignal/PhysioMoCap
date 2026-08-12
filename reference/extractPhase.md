# Extract a single phase from segmented data

Extract a single phase from segmented data

## Usage

``` r
extractPhase(x, phase_name, search_subphases = TRUE)
```

## Arguments

- x:

  A segmented_phases object

- phase_name:

  Name of the phase to extract

- search_subphases:

  Whether to search within subphases

## Value

A matrix of phase data

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`phaseTiming()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseTiming.md),
[`getPhaseData()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseData.md)
