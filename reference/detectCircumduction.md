# Detect circumduction (excessive lateral swing trajectory)

Circumduction is a lateral (outward) swing of the foot/hip used to
advance a functionally long limb (e.g. with stiff knee or drop foot). It
is quantified as the peak lateral excursion of the foot (or hip) during
swing relative to the stance-phase baseline.

## Usage

``` r
detectCircumduction(
  foot_ml,
  swing = c(60, 100),
  stance = c(0, 55),
  threshold = 0.04,
  severe = 0.12,
  lateral_sign = 1
)
```

## Arguments

- foot_ml:

  Medio-lateral foot (or hip) position over one gait cycle, in metres,
  with lateral being positive (see `lateral_sign`).

- swing, stance:

  Percentage windows of swing and stance (defaults `c(60, 100)` and
  `c(0, 55)`).

- threshold:

  Lateral excursion (m) above which circumduction is flagged (default
  0.04).

- severe:

  Lateral excursion mapped to severity 1 (default 0.12 m).

- lateral_sign:

  `+1` if positive `foot_ml` is lateral, `-1` otherwise.

## Value

A `gait_pattern_flag` object.

## References

Perry J, Burnfield JM (2010); Kerrigan DC, et al. (2000).

## See also

[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md)
