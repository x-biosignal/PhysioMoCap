# Compute acceleration from position or velocity data

Computes acceleration (second derivative) from position or velocity
assays. If velocity assays already exist, differentiates those (first
derivative of velocity). Otherwise, computes the second derivative of
position directly.

## Usage

``` r
computeAcceleration(
  pe,
  assay_names = NULL,
  method = "central",
  sampling_rate = NULL
)
```

## Arguments

- pe:

  A PhysioExperiment object.

- assay_names:

  Character vector of assay names to differentiate. If NULL (default),
  auto-detects velocity_x/y/z (preferred) or position_x/y/z assays.

- method:

  Finite difference method: "central" (default), "forward", or
  "backward".

- sampling_rate:

  Sampling rate in Hz. If NULL (default), uses `samplingRate(pe)`.

## Value

PhysioExperiment with new accel_x, accel_y, accel_z assays added.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
for first-order derivatives,
[`computeJerk()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJerk.md)
for third-order derivatives,
[`differentiate()`](https://x-biosignal.github.io/PhysioMoCap/reference/differentiate.md)
for general-purpose numerical differentiation.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
pe <- computeAcceleration(pe)
} # }
```
