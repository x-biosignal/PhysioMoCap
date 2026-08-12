# Compute 3D lower-limb joint moments with inverse dynamics

Computes ankle, knee, and hip net moment vectors in 3D from joint-center
coordinates, GRF, COP, and segment inertial properties, using a
recursive link-segment Newton-Euler chain (foot -\> shank -\> thigh).

## Usage

``` r
inverseDynamics3D(
  joints,
  grf,
  sampling_rate,
  angles = NULL,
  angular_velocity = NULL,
  angular_acceleration = NULL,
  inertial = NULL,
  angle_unit = c("radian", "degree"),
  model = c("newton_euler", "quasi_static"),
  body_mass = NULL,
  body_height = NULL,
  gravity = .GRAVITY,
  vertical = c("y", "z")
)
```

## Arguments

- joints:

  Matrix/data.frame with columns `ankle_x`, `ankle_y`, `ankle_z`,
  `knee_x`, `knee_y`, `knee_z`, `hip_x`, `hip_y`, `hip_z`, and - for
  `model = "newton_euler"` - the foot distal end `toe_x`, `toe_y`,
  `toe_z`.

- grf:

  Matrix/data.frame with columns `fx`, `fy`, `fz` and optional `cop_x`,
  `cop_y`, `cop_z` (and, for `model = "newton_euler"`, optional free
  moments `tx`, `ty`, `tz`).

- sampling_rate:

  Sampling rate in Hz.

- angles:

  Optional matrix/data.frame containing 3D joint angles with columns
  `ankle_x`, `ankle_y`, `ankle_z`, `knee_x`, `knee_y`, `knee_z`,
  `hip_x`, `hip_y`, `hip_z`.

- angular_velocity:

  Optional 3D joint angular velocity table.

- angular_acceleration:

  Optional 3D joint angular acceleration table.

- inertial:

  Optional data.frame from
  [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md).
  Required for `model = "newton_euler"` unless `body_mass` is given;
  under `model = "quasi_static"` it only supplies an `I * alpha`
  correction and is ignored when omitted.

- angle_unit:

  Unit of angle-related inputs: `"radian"` or `"degree"`.

- model:

  Which dynamics model to use: `"newton_euler"` (the default, the full
  recursive chain via
  [`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md))
  or `"quasi_static"` (the legacy massless-segment approximation; see
  [`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)).

- body_mass:

  Body mass in kg, used to build the segment inertia table with
  [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
  when `inertial` is not supplied.

- body_height:

  Body height in m, used when segment lengths must be estimated from
  stature rather than measured from the markers.

- gravity:

  Gravitational acceleration in m/s^2.

- vertical:

  Which coordinate axis points up, `"y"` (default) or `"z"`. Gravity
  acts along the negative of this axis, so it must match the laboratory
  convention of `joints`. The default follows this package's marker
  convention (x antero-posterior, y vertical, z medio-lateral) and the
  sagittal
  [`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md);
  note that force-plate hardware normally reports the vertical force as
  `fz`, so `grf` may need reordering to match. A mismatch is checked
  against the marker geometry and warned about, because the wrong axis
  silently removes every gravitational moment. Used only by
  `model = "newton_euler"`; the quasi-static model has no gravity term
  and therefore ignores it.

## Value

A data.frame with time and moment components: `*_moment_x`,
`*_moment_y`, `*_moment_z`. If angular velocity is available,
`*_power_total` columns are included. `model = "newton_euler"` also
returns the proximal joint reaction force components (`ankle_fx`,
`ankle_fy`, `ankle_fz`, ...).

## Details

See
[`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
for what the two models compute and why the quasi-static one is retained
only for reproducibility. The 3D moment balance uses an axisymmetric
segment inertia and neglects the gyroscopic \\\omega \times I \omega\\
term and any spin about the segment long axis, which is not observable
from two joint centres.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md)
for the underlying recursion,
[`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
for sagittal-plane inverse dynamics,
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
for segment inertial properties,
[`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md)
for joint power calculation.

## Examples

``` r
n <- 200
joints <- data.frame(
  ankle_x = rep(0.00, n), ankle_y = rep(0.05, n), ankle_z = rep(0.00, n),
  toe_x   = rep(0.15, n), toe_y   = rep(0.01, n), toe_z   = rep(0.00, n),
  knee_x = rep(0.00, n),  knee_y = rep(0.45, n),  knee_z = rep(0.00, n),
  hip_x = rep(0.00, n),   hip_y = rep(0.85, n),   hip_z = rep(0.00, n)
)
grf <- data.frame(
  fx = rep(50, n), fy = rep(700, n), fz = rep(0, n),
  cop_x = rep(0.02, n), cop_y = rep(0, n), cop_z = rep(0, n)
)
out <- inverseDynamics3D(joints, grf, sampling_rate = 100, body_mass = 70)
```
