# Get phase timing information

Get phase timing information

## Usage

``` r
phaseTiming(x, as_percent = TRUE)
```

## Arguments

- x:

  A segmented_phases object

- as_percent:

  Return timing as percentage (TRUE) or seconds (FALSE)

## Value

A data.frame with phase timing information

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`phaseDurations()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseDurations.md),
[`phaseRatios()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseRatios.md)

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
phaseTiming(segmentPhases(data, events, schema_gait))
#>    phase        label    start       end duration
#> 1 stance Stance Phase  0.00000  60.60606 60.60606
#> 2  swing  Swing Phase 60.60606 100.00000 39.39394
```
