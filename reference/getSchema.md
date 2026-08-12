# Get a pre-built schema by name

Get a pre-built schema by name

## Usage

``` r
getSchema(name)
```

## Arguments

- name:

  Name of the schema ("gait", "running", "jump", "throw", "balance",
  "cutting", "cycling")

## Value

A TaskSchema object

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`listSchemas()`](https://x-biosignal.github.io/PhysioMoCap/reference/listSchemas.md),
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md),
[`validateSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateSchema.md)

## Examples

``` r
gait <- getSchema("gait")
jump <- getSchema("jump")
```
