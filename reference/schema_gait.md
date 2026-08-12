# Pre-built Gait Cycle Schema

Task schema for walking gait analysis with standard events and phases.

## Usage

``` r
schema_gait
```

## Format

A TaskSchema object with:

- events:

  Heel strike (x2), foot flat, midstance, heel off, toe off

- phases:

  Stance (with loading, midstance, propulsion subphases), Swing

- normalization:

  cycle (0-100%)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[`getSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/getSchema.md),
[schema_running](https://x-biosignal.github.io/PhysioMoCap/reference/schema_running.md)

## Examples

``` r
print(schema_gait)
#> TaskSchema: Gait Cycle 
#>   Type: gait 
#>   Normalization: cycle 
#>   Normalized length: 101 
#>   Events: 6 
#>      Heel Strike -> Foot Flat -> Midstance -> Heel Off -> Toe Off -> Heel Strike 2 
#>   Phases: 2 
#>      Stance Phase, Swing Phase 
#>   Metrics: 14 
#>      peak_flexion, peak_extension, rom, peak_moment, peak_power , ... 
getEventNames(schema_gait)
#> [1] "hs1" "ff"  "ms"  "ho"  "to"  "hs2"
getPhaseNames(schema_gait)
#> [1] "stance" "swing" 
```
