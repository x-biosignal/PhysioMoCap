# Pre-built Cutting/Change of Direction Schema

Task schema for cutting and change of direction analysis.

## Usage

``` r
schema_cutting
```

## Format

A TaskSchema object with COD-specific events and phases.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_running](https://x-biosignal.github.io/PhysioMoCap/reference/schema_running.md)

## Examples

``` r
print(schema_cutting)
#> TaskSchema: Change of Direction 
#>   Type: cutting 
#>   Normalization: phase 
#>   Normalized length: 101 
#>   Events: 7 
#>      Approach Start -> Penultimate Contact -> Penultimate Toe Off -> Plant Foot Contact -> Peak Knee Flexion -> Push Off -> Re-acceleration 
#>   Phases: 5 
#>      Approach, Penultimate Step, Weight Acceptance, Push Off, Re-acceleration 
#>   Metrics: 13 
#>      approach_velocity, exit_velocity, velocity_deficit, deceleration_impulse, braking_force , ... 
```
