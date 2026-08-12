# Scale a body model from marker-measured segment lengths

Measures each lower-limb segment length from joint-centre trajectories
(the mean over frames of the distance between the segment's endpoints)
and scales the de Leva model to the subject's body mass with those
measured lengths.

## Usage

``` r
scaleBodyModel(joints, body_mass, model = c("deLeva_male", "deLeva_female"))
```

## Arguments

- joints:

  A matrix/data.frame with `ankle`, `toe`, `knee`, `hip` joint
  coordinate columns (`_x`/`_y`, plus `_z` for 3D), as for
  [`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md).

- body_mass:

  Subject body mass in kg.

- model:

  `"deLeva_male"` or `"deLeva_female"`.

## Value

A segment inertia data.frame with the marker-measured `length`.

## See also

[`scaleSegmentModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/scaleSegmentModel.md),
[`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md)

## Examples

``` r
n <- 10
joints <- data.frame(
  ankle_x = rep(0, n), ankle_y = rep(0.08, n), toe_x = rep(0.15, n),
  toe_y = rep(0.03, n), knee_x = rep(0, n), knee_y = rep(0.48, n),
  hip_x = rep(0, n), hip_y = rep(0.90, n))
scaleBodyModel(joints, body_mass = 70)
#>   segment    length  mass mass_fraction com_proximal_fraction
#> 1    foot 0.1581139 1.015        0.0145                 0.500
#> 2   shank 0.4000000 3.255        0.0465                 0.433
#> 3   thigh 0.4200000 9.912        0.1416                 0.433
#>   radius_gyration_fraction     inertia
#> 1                    0.475 0.005725234
#> 2                    0.302 0.047499043
#> 3                    0.323 0.182416836
```
