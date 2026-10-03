# Get a phase by name from a TaskSchema

Get a phase by name from a TaskSchema

## Usage

``` r
getPhase(schema, phase_name, search_subphases = TRUE)
```

## Arguments

- schema:

  A TaskSchema object

- phase_name:

  Name of the phase to retrieve

- search_subphases:

  Whether to search within subphases

## Value

A Phase object or NULL if not found

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`getPhaseNames()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseNames.md),
[`getPhaseColors()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseColors.md),
[`getEvent()`](https://x-biosignal.github.io/PhysioMoCap/reference/getEvent.md)

## Examples

``` r
getPhase(schema_gait, getPhaseNames(schema_gait)[1])
#> Phase:Stance Phase
#>   Name: stance
#>   Events: hs1 -> to
#>   Color: #E8F4F8
#>   Subphases:
#>     Phase:Loading Response
#>       Name: loading
#>       Events: hs1 -> ff
#>       Color: #B8D4E3
#>     Phase:Midstance
#>       Name: midstance
#>       Events: ff -> ho
#>       Color: #A8C4D3
#>     Phase:Propulsion
#>       Name: propulsion
#>       Events: ho -> to
#>       Color: #98B4C3
```
