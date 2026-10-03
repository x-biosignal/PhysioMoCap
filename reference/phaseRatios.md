# Calculate phase ratios

Calculate phase ratios

## Usage

``` r
phaseRatios(x, reference = "total")
```

## Arguments

- x:

  A segmented_phases object

- reference:

  Reference for ratio calculation ("total" or phase name)

## Value

Named numeric vector of phase ratios

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`phaseDurations()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseDurations.md),
[`phaseTiming()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseTiming.md),
[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)

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
phaseRatios(segmentPhases(data, events, schema_gait))
#>    stance     swing 
#> 0.6039604 0.3960396 
```
