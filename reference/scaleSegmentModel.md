# Scale a de Leva segment inertia model to a subject

Scales the de Leva (1996) body-segment inertial parameters to a
subject's body mass and segment lengths (or stature). A thin,
explicitly-named wrapper around
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md).

## Usage

``` r
scaleSegmentModel(
  body_mass,
  segment_lengths = NULL,
  body_height = NULL,
  model = c("deLeva_male", "deLeva_female")
)
```

## Arguments

- body_mass:

  Subject body mass in kg.

- segment_lengths:

  Optional named vector of `foot`, `shank`, `thigh` lengths (m). If
  omitted, `body_height` is used with typical ratios.

- body_height:

  Subject stature in m (used when `segment_lengths` is omitted).

- model:

  `"deLeva_male"` or `"deLeva_female"`.

## Value

A segment inertia data.frame (see
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)).

## References

de Leva P (1996). "Adjustments to Zatsiorsky-Seluyanov's segment inertia
parameters." J Biomech, 29(9), 1223-1230.

## See also

[`scaleBodyModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/scaleBodyModel.md),
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md),
[`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md)

## Examples

``` r
scaleSegmentModel(body_mass = 68, body_height = 1.70)
#>   segment length   mass mass_fraction com_proximal_fraction
#> 1    foot 0.2584 0.9860        0.0145                 0.500
#> 2   shank 0.4182 3.1620        0.0465                 0.433
#> 3   thigh 0.4165 9.6288        0.1416                 0.433
#>   radius_gyration_fraction    inertia
#> 1                    0.475 0.01485420
#> 2                    0.302 0.05043637
#> 3                    0.323 0.17426382
```
