# Detect stiff-knee gait (reduced / delayed peak swing knee flexion)

Stiff-knee gait is marked by reduced peak knee flexion in swing (normal
\\\approx 60^{\circ}\\ near 73\\ (Perry & Burnfield; Goldberg et al.
2006).

## Usage

``` r
detectStiffKnee(
  knee_flexion,
  swing = c(60, 100),
  normal_peak = 60,
  threshold = 45,
  severe_floor = 10,
  delay_threshold = 80
)
```

## Arguments

- knee_flexion:

  Knee flexion angle (degrees, flexion positive) over one normalised
  gait cycle.

- swing:

  Percentage window of swing phase (default `c(60, 100)`).

- normal_peak:

  Normal peak swing knee flexion in degrees (default 60).

- threshold:

  Peak below which stiff-knee is flagged (default 45).

- severe_floor:

  Peak flexion mapped to severity 1 (default 10).

- delay_threshold:

  Peak-timing percentage above which the peak is considered delayed
  (default 80).

## Value

A `gait_pattern_flag` object.

## References

Perry J, Burnfield JM (2010); Goldberg SR, et al. (2006).

## See also

[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md),
[`gaitPatternLibrary()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitPatternLibrary.md)

## Examples

``` r
# normal knee flexion peaks ~60 deg in swing
k <- c(seq(5, 18, length.out = 30), seq(18, 5, length.out = 30),
       60 * sin(seq(0, pi, length.out = 41)))
detectStiffKnee(k)
#> <gait_pattern_flag> stiff_knee: normal (severity 0.00)
#>   peak_swing_knee_flexion_deg = 60 (threshold 45, normal 60)
```
