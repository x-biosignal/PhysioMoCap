# Detect push-off deficit (reduced ankle A2 power / plantarflexor output)

Reduced ankle plantarflexor push-off is quantified from the peak
positive ankle power in late stance (the A2 burst; normal \\\approx
3-4\\ W/kg) or, equivalently, the peak late-stance plantarflexor moment.

## Usage

``` r
detectPushOffDeficit(
  ankle_power,
  window = c(40, 62),
  normal_peak = 3.5,
  threshold = 2,
  metric_name = "peak_ankle_A2_power"
)
```

## Arguments

- ankle_power:

  Ankle joint power over one gait cycle. Interpreted as W/kg (or the
  peak ankle plantarflexor moment if `metric_name` is set).

- window:

  Percentage window of late stance / push-off (default `c(40, 62)`).

- normal_peak:

  Normal peak A2 power (default 3.5 W/kg).

- threshold:

  Peak below which a deficit is flagged (default 2.0).

- metric_name:

  Label for the metric (default `"peak_ankle_A2_power"`).

## Value

A `gait_pattern_flag` object.

## References

Perry J, Burnfield JM (2010); Winter DA (2009).

## See also

[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md)

## Examples

``` r
pct <- seq(0, 100, length.out = 101)
ankle_power <- -0.6 * exp(-((pct - 15) / 8)^2)
push <- pct > 40 & pct < 62
ankle_power[push] <- 1.0 * sin(pi * (pct[push] - 40) / 22)
detectPushOffDeficit(ankle_power)
#> <gait_pattern_flag> push_off_deficit: FLAGGED (severity 0.71)
#>   peak_ankle_A2_power = 1 (threshold 2, normal 3.5)
```
