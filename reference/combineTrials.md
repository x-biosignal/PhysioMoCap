# Combine multiple trials with segmented phases

Combine multiple trials with segmented phases

## Usage

``` r
combineTrials(..., labels = NULL)
```

## Arguments

- ...:

  segmented_phases objects to combine

- labels:

  Optional labels for each trial

## Value

A multi_trial_phases object

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md),
[`batchNormalize()`](https://x-biosignal.github.io/PhysioMoCap/reference/batchNormalize.md),
[`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md)

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
phases <- segmentPhases(data, events, schema_gait)
combineTrials(phases, phases, labels = c("t1", "t2"))
#> Multi-Trial Segmented Phases
#> Schema: Gait Cycle 
#> Number of trials: 2 
#> Trial labels: t1, t2 
```
