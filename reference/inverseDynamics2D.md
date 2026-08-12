# Compute 2D lower-limb joint moments with inverse dynamics

Computes sagittal-plane ankle, knee, and hip net moments from
joint-center coordinates, GRF, COP, and segment inertial properties,
using a recursive link-segment Newton-Euler chain (foot -\> shank -\>
thigh).

## Usage

``` r
inverseDynamics2D(
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
  gravity = .GRAVITY
)
```

## Arguments

- joints:

  Matrix/data.frame with columns `ankle_x`, `ankle_y`, `knee_x`,
  `knee_y`, `hip_x`, `hip_y`, and - for `model = "newton_euler"` - the
  foot distal end `toe_x`, `toe_y`.

- grf:

  Matrix/data.frame with at least `fx` and `fy` columns, and optionally
  `cop_x` and `cop_y`.

- sampling_rate:

  Sampling rate in Hz.

- angles:

  Optional matrix/data.frame with columns `ankle`, `knee`, `hip` (joint
  angles).

- angular_velocity:

  Optional matrix/data.frame with columns `ankle`, `knee`, `hip`.

- angular_acceleration:

  Optional matrix/data.frame with columns `ankle`, `knee`, `hip`.

- inertial:

  Optional data.frame from
  [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md).
  Required for `model = "newton_euler"` unless `body_mass` is given;
  under `model = "quasi_static"` it only supplies an `I * alpha`
  correction and is ignored when omitted.

- angle_unit:

  Unit of `angles`: `"radian"` or `"degree"`.

- model:

  Which dynamics model to use. `"newton_euler"` (the default) runs the
  full recursive link-segment Newton-Euler chain via
  [`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md).
  `"quasi_static"` is the legacy massless-segment approximation,
  retained only for reproducing older results (see Details).

- body_mass:

  Body mass in kg. Used to build the segment inertia table with
  [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
  when `inertial` is not supplied.

- body_height:

  Body height in m, passed to
  [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
  when segment lengths must be estimated from stature. If `NULL`,
  segment lengths are measured from the marker data with
  [`scaleBodyModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/scaleBodyModel.md).

- gravity:

  Gravitational acceleration in m/s^2.

## Value

A data.frame with time index and joint moments (`ankle_moment`,
`knee_moment`, `hip_moment`). If angular velocity is available,
corresponding power columns are included. `model = "newton_euler"` also
returns the proximal joint reaction forces (`ankle_fx`, `ankle_fy`,
...).

## Details

The default `"newton_euler"` model propagates reactions distal to
proximal: the ground reaction force and free moment enter at the foot,
and every segment contributes its weight \\m g\\, its linear inertia \\m
a\_{com}\\ and its angular inertia \\I \alpha\\. Segment centres of mass
come from the anthropometric ratios in `inertial`, and their linear and
angular accelerations from numerical differentiation of the marker
trajectories, so a segment mass source (`inertial` or `body_mass`) and
the foot distal end (`toe_x`, `toe_y`) are required.

Because the recursion differentiates the marker trajectories twice, it
amplifies marker noise: the joint moments are only as good as the
smoothing applied beforehand. On a static limb sampled at 200 Hz, 1 mm
of white marker noise produces a spurious moment about 24 times the true
value; a 6 Hz zero-lag low-pass
([`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md),
or
[`filterSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterSignals.md)
on the positions) reduces that by more than an order of magnitude.
Filter the marker data before calling this function. The quasi-static
model never differentiated positions, so this exposure is new.

`"quasi_static"` reproduces the pre-1.0 behaviour: each joint moment is
the moment of the *ground reaction force alone* about that joint centre,
plus an optional \\I \alpha\\ term. It omits segment weight and linear
inertia entirely, so it returns identically zero whenever the limb is
off the ground (the whole swing phase) and underestimates stance
moments - at the hip by roughly 8% in quiet standing. It is kept only so
that analyses published against the old implementation can be
reproduced, and emits a message when selected.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md)
for the underlying recursion,
[`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
for 3D inverse dynamics computation,
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
for segment inertial properties,
[`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md)
for joint power calculation.

## Examples

``` r
n <- 200
joints <- data.frame(
  ankle_x = rep(0.00, n), ankle_y = rep(0.05, n),
  toe_x   = rep(0.15, n), toe_y   = rep(0.01, n),
  knee_x = rep(0.00, n),  knee_y = rep(0.45, n),
  hip_x = rep(0.00, n),   hip_y = rep(0.85, n)
)
grf <- data.frame(fx = rep(0, n), fy = abs(sin(seq(0, pi, length.out = n))) * 800,
                  cop_x = rep(0.02, n), cop_y = rep(0, n))
id <- inverseDynamics2D(joints, grf, sampling_rate = 100, body_mass = 70)
```
