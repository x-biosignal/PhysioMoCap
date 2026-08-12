# Compute scalar speed from velocity

Computes the magnitude of the velocity vector (Euclidean norm) at each
time point for each marker/keypoint.

## Usage

``` r
computeSpeed(pe, velocity_assays = NULL)
```

## Arguments

- pe:

  A PhysioExperiment object containing velocity assays.

- velocity_assays:

  Character vector of velocity assay names. If NULL (default),
  auto-detects velocity_x/y/z or velocity_kp_x/y.

## Value

PhysioExperiment with a new "speed" assay containing the scalar speed:
`sqrt(vx^2 + vy^2 + vz^2)`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
for computing velocity components,
[`computeAcceleration()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeAcceleration.md)
for computing acceleration.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
pe <- computeVelocity(pe)
pe <- computeSpeed(pe)
} # }
```
