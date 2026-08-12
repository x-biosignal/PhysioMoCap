# Time axis for normalized data

Generates an appropriate time axis for normalized data.

## Usage

``` r
normalizedTimeAxis(
  norm_length,
  method = "cycle",
  unit = c("percent", "normalized", "degrees")
)
```

## Arguments

- norm_length:

  Length of normalized data

- method:

  Normalization method used

- unit:

  Output unit ("percent", "normalized", "degrees")

## Value

Numeric vector of time values

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md),
[`batchNormalize()`](https://x-biosignal.github.io/PhysioMoCap/reference/batchNormalize.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)

## Examples

``` r
# 0-100% axis
t_pct <- normalizedTimeAxis(101, method = "cycle", unit = "percent")

# 0-360 degrees for cycling
t_deg <- normalizedTimeAxis(361, method = "cycle", unit = "degrees")
```
