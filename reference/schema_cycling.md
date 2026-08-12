# Pre-built Cycling Schema

Task schema for cycling pedal stroke analysis.

## Usage

``` r
schema_cycling
```

## Format

A TaskSchema object with cycling-specific events and phases.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_running](https://x-biosignal.github.io/PhysioMoCap/reference/schema_running.md)

## Examples

``` r
print(schema_cycling)
#> TaskSchema: Pedal Cycle 
#>   Type: cycling 
#>   Normalization: cycle 
#>   Normalized length: 361 
#>   Events: 6 
#>      Top Dead Center -> Power Phase Start -> Peak Torque -> Bottom Dead Center -> Recovery Midpoint -> Top Dead Center 2 
#>   Phases: 2 
#>      Extension/Power, Flexion/Recovery 
#>   Metrics: 12 
#>      peak_torque, mean_torque, peak_power, mean_power, cadence , ... 
```
