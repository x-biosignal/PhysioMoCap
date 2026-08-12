# Estimate segment inertial properties for lower-limb inverse dynamics

Builds foot/shank/thigh inertial parameters from body mass and segment
lengths using De Leva-style coefficients.

## Usage

``` r
estimateSegmentInertia(
  body_mass,
  segment_lengths = NULL,
  body_height = NULL,
  model = c("deLeva_male", "deLeva_female")
)
```

## Arguments

- body_mass:

  Body mass in kilograms.

- segment_lengths:

  Named numeric vector with `foot`, `shank`, and `thigh` lengths in
  meters. If `NULL`, lengths are estimated from `body_height`.

- body_height:

  Body height in meters, required when `segment_lengths = NULL`.

- model:

  Anthropometric coefficient set: `"deLeva_male"` or `"deLeva_female"`.

## Value

A data.frame with segment mass, COM fraction, radius of gyration, and
segment moment of inertia about COM.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`segmentParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentParameters.md)
for body segment inertial parameters,
[`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
for 2D inverse dynamics computation,
[`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
for 3D inverse dynamics computation.

## Examples

``` r
inertia <- estimateSegmentInertia(
  body_mass = 70,
  segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
)
```
