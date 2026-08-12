# Limits of Stability (LOS) reaction time, excursion and directional control

Quantifies a single limits-of-stability leaning trial toward a target
direction from a CoP trace: reaction time, endpoint and maximum
excursion (optionally as a percentage of a theoretical limit), and
directional control.

## Usage

``` r
limitsOfStability(
  cop,
  sampling_rate,
  target,
  ap = NULL,
  ml = NULL,
  onset_cue = 1L,
  onset_frac = 0.05,
  los_distance = NULL
)
```

## Arguments

- cop, ap, ml:

  CoP trace, as in
  [`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md)
  (a single leaning trial).

- sampling_rate:

  Sampling rate in Hz.

- target:

  Target direction: an angle in degrees (0 = +AP/forward, 90 =
  +ML/right, measured counter-clockwise from forward) or a length-2
  numeric `c(ap, ml)` direction vector.

- onset_cue:

  Sample index of the go cue (default 1).

- onset_frac:

  Fraction of the maximum excursion defining movement onset (default
  0.05).

- los_distance:

  Optional theoretical limit-of-stability distance (CoP units) for the
  target; if supplied, excursions are also returned as a percentage of
  it.

## Value

A `los_result` object with `reaction_time`, `endpoint_excursion`,
`max_excursion`, optional `endpoint_pct` / `max_pct`, and
`directional_control`.

## Details

The CoP is projected onto the unit vector toward the target. Reaction
time is the delay from the go cue to movement onset (projection first
exceeding `onset_frac` of the maximum excursion). Endpoint excursion is
the projection at the end of the initial movement (its first local
maximum after onset); maximum excursion is the largest projection.
Directional control is \\100 \times\\ the path travelled toward the
target divided by the total path length.

## References

Nashner LM (1997). "Computerized dynamic posturography."

## See also

[`sensoryOrganizationTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/sensoryOrganizationTest.md),
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md)

## Examples

``` r
t <- seq(0, 3, by = 0.01)
lean <- pmin(t / 1.5, 1) * 5             # ramp forward to 5 units
cop <- data.frame(cop_x = rnorm(length(t), 0, 0.02), cop_y = lean)
limitsOfStability(cop, sampling_rate = 100, target = 0)
#> <los_result>
#>   reaction time: 0.080 s
#>   endpoint excursion: 5   max excursion: 5
#>   directional control: 52.4%
```
