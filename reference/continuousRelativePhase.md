# Continuous relative phase between two joints

The phase-plane coordination measure (Hamill et al. 2000): each joint
angle is mapped to a phase angle from its (normalised) phase portrait,
and the continuous relative phase is their difference through the
movement. Its mean absolute value (MARP) summarises whether the joints
move more in-phase (near 0) or out-of-phase (near 180).

## Usage

``` r
continuousRelativePhase(angle1, angle2, normalize = TRUE)
```

## Arguments

- angle1, angle2:

  Numeric joint-angle time series of equal length, one movement cycle
  (typically time-normalised); `angle1` is the reference (e.g. proximal)
  joint.

- normalize:

  Normalise the phase portrait (recommended; corrects for amplitude
  differences).

## Value

a `crp_result` list: `crp` (degrees, wrapped to +/-180), `phase1`,
`phase2` (phase angles, degrees) and `marp` (mean absolute relative
phase).

## References

Hamill J, et al. (2000) Clin Biomech 15:S31-S39.

## See also

[`vectorCoding()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorCoding.md),
[`coordinationVariability()`](https://x-biosignal.github.io/PhysioMoCap/reference/coordinationVariability.md)

## Examples

``` r
t <- seq(0, 2 * pi, length.out = 101)
continuousRelativePhase(sin(t), sin(t))$marp        # in-phase ~ 0
#> [1] 0
```
