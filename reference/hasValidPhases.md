# Check if all phases are valid

Check if all phases are valid

## Usage

``` r
hasValidPhases(x)
```

## Arguments

- x:

  A segmented_phases object

## Value

Logical indicating if all phases have valid data

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`getPhaseData()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseData.md),
[`extractPhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractPhase.md)

## Examples

``` r
set.seed(123)
data <- matrix(rnorm(200), 100, 2)
events <- data.frame(
  event = c("hs1","ff","ms","ho","to","hs2"),
  label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
  index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
  percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
  confidence = rep(1, 6), stringsAsFactors = FALSE)
class(events) <- c("detected_events", "data.frame")
attr(events, "sampling_rate") <- 100
hasValidPhases(segmentPhases(data, events, schema_gait))
#> [1] TRUE
```
