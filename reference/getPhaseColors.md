# Get phase colors from a TaskSchema

Get phase colors from a TaskSchema

## Usage

``` r
getPhaseColors(schema, include_subphases = FALSE)
```

## Arguments

- schema:

  A TaskSchema object

- include_subphases:

  Whether to include subphase colors

## Value

Named character vector of colors (phase name -\> color)

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`getPhaseNames()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseNames.md),
[`getPhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhase.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md)

## Examples

``` r
getPhaseColors(schema_gait)
#>    stance     swing 
#> "#E8F4F8" "#FFF4E8" 
```
