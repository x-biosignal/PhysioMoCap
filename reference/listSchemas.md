# Get list of all pre-built schemas

Get list of all pre-built schemas

## Usage

``` r
listSchemas()
```

## Value

Named list of all available pre-built TaskSchema objects

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`getSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/getSchema.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[`validateSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateSchema.md)

## Examples

``` r
schemas <- listSchemas()
names(schemas)
#> [1] "gait"    "running" "jump"    "throw"   "balance" "cutting" "cycling"
```
