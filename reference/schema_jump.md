# Pre-built Jump Schema

Task schema for vertical jump analysis (countermovement, drop jump,
etc.).

## Usage

``` r
schema_jump
```

## Format

A TaskSchema object with jump-specific events and phases.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_throw](https://x-biosignal.github.io/PhysioMoCap/reference/schema_throw.md)

## Examples

``` r
print(schema_jump)
#> TaskSchema: Jump 
#>   Type: jump 
#>   Normalization: phase 
#>   Normalized length: 101 
#>   Events: 7 
#>      Movement Start -> Unweighting End -> Takeoff -> Peak Height -> Landing -> Peak Landing GRF -> Stabilization 
#>   Phases: 4 
#>      Unweighting, Propulsion, Flight, Landing 
#>   Metrics: 13 
#>      jump_height, peak_power, mean_power, peak_velocity, peak_grf_takeoff , ... 
```
