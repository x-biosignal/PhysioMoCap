# Compute velocity from position data

Computes velocity (first derivative) from position assays in a
PhysioExperiment object using finite differences.

## Usage

``` r
computeVelocity(
  pe,
  assay_names = NULL,
  method = "central",
  sampling_rate = NULL
)
```

## Arguments

- pe:

  A PhysioExperiment object containing position assays.

- assay_names:

  Character vector of assay names to differentiate. If NULL (default),
  auto-detects position_x/y/z or keypoint_x/y assays.

- method:

  Finite difference method: "central" (default), "forward", or
  "backward".

- sampling_rate:

  Sampling rate in Hz. If NULL (default), uses `samplingRate(pe)`.

## Value

PhysioExperiment with new velocity assays added. For 3D marker data,
assays named velocity_x, velocity_y, velocity_z. For 2D keypoint data,
assays named velocity_kp_x, velocity_kp_y.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeAcceleration()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeAcceleration.md)
for second-order derivatives,
[`computeSpeed()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeSpeed.md)
for scalar speed from velocity components,
[`differentiate()`](https://x-biosignal.github.io/PhysioMoCap/reference/differentiate.md)
for general-purpose numerical differentiation.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
pe <- computeVelocity(pe)
# velocity_x, velocity_y, velocity_z assays are now present
} # }
```
