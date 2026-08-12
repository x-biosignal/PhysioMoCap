# Pre-built Running Schema

Task schema for running gait analysis.

## Usage

``` r
schema_running
```

## Format

A TaskSchema object with running-specific events and phases.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_jump](https://x-biosignal.github.io/PhysioMoCap/reference/schema_jump.md)

## Examples

``` r
print(schema_running)
#> TaskSchema: Running Cycle 
#>   Type: running 
#>   Normalization: cycle 
#>   Normalized length: 101 
#>   Events: 5 
#>      Initial Contact -> Midstance -> Toe Off -> Mid-Swing -> Initial Contact 2 
#>   Phases: 2 
#>      Stance Phase, Swing Phase 
#>   Metrics: 11 
#>      contact_time, flight_time, duty_factor, step_frequency, step_length , ... 
```
