# Pre-built Balance Schema

Task schema for postural control/balance analysis.

## Usage

``` r
schema_balance
```

## Format

A TaskSchema object for continuous balance assessment.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[schema_gait](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md),
[schema_cutting](https://x-biosignal.github.io/PhysioMoCap/reference/schema_cutting.md)

## Examples

``` r
print(schema_balance)
#> TaskSchema: Postural Control 
#>   Type: balance 
#>   Normalization: absolute 
#>   Normalized length:  
#>   Events: 0 
#>   Phases: 0 
#>   Metrics: 16 
#>      cop_velocity_ap, cop_velocity_ml, cop_velocity_resultant, cop_path_length, cop_area_95 , ... 
```
