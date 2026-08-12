# Pre-built Throwing Schema

Task schema for throwing motion analysis (baseball, softball, etc.).

## Usage

``` r
schema_throw
```

## Format

A TaskSchema object with throwing-specific events and phases.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_cutting](https://x-biosignal.github.io/PhysioMoCap/reference/schema_cutting.md)

## Examples

``` r
print(schema_throw)
#> TaskSchema: Throwing Motion 
#>   Type: throw 
#>   Normalization: landmark 
#>   Normalized length: 101 
#>   Events: 7 
#>      Wind-up Start -> Lead Leg Max Height -> Stride Foot Contact -> Max External Rotation -> Ball Release -> Max Internal Rotation -> Follow Through End 
#>   Phases: 6 
#>      Wind-up, Stride, Arm Cocking, Arm Acceleration, Arm Deceleration, Follow Through 
#>   Metrics: 10 
#>      ball_velocity, shoulder_er_velocity, shoulder_ir_velocity, elbow_extension_velocity, trunk_rotation_velocity , ... 
```
