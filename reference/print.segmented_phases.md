# Print method for segmented phases

Print method for segmented phases

## Usage

``` r
# S3 method for class 'segmented_phases'
print(x, ...)
```

## Arguments

- x:

  A segmented_phases object

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
print(segmentPhases(data, events, schema_gait))
#> Segmented Phases
#> Schema: Gait Cycle 
#> Sampling rate: 100 Hz
#> Total samples: 100 
#> Channels: 2 
#> 
#> Phases:
#>   Stance Phase: 0.0% - 60.6% (60.6%)
#>   Swing Phase: 60.6% - 100.0% (39.4%)
```
