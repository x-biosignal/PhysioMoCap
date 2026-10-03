# Print method for multi-trial phases

Print method for multi-trial phases

## Usage

``` r
# S3 method for class 'multi_trial_phases'
print(x, ...)
```

## Arguments

- x:

  A multi_trial_phases object

- ...:

  Additional arguments (unused)

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
print(combineTrials(phases, phases, labels = c("t1", "t2")))
#> Multi-Trial Segmented Phases
#> Schema: Gait Cycle 
#> Number of trials: 2 
#> Trial labels: t1, t2 
```
