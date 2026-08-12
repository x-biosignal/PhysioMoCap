# Compute jerk from position data

Computes jerk (third derivative of position) from position assays.

## Usage

``` r
computeJerk(pe, method = "central", sampling_rate = NULL)
```

## Arguments

- pe:

  A PhysioExperiment object containing position assays.

- method:

  Finite difference method: "central" (default), "forward", or
  "backward".

- sampling_rate:

  Sampling rate in Hz. If NULL (default), uses `samplingRate(pe)`.

## Value

PhysioExperiment with new jerk_x, jerk_y, jerk_z assays added.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeAcceleration()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeAcceleration.md)
for second-order derivatives,
[`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
for first-order derivatives,
[`differentiate()`](https://x-biosignal.github.io/PhysioMoCap/reference/differentiate.md)
for general-purpose numerical differentiation.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 100, n_markers = 4, sr = 120)
pe <- computeJerk(pe)
} # }
```
