# Calculate joint angles from marker positions

Computes joint angles from 3D (or 2D) position data stored in a
PhysioExperiment object. Each joint is defined by three points:
proximal, joint (vertex), and distal. The angle at the vertex is
computed using the specified convention.

## Usage

``` r
calculateJointAngles(
  pe,
  joints,
  convention = c("3point", "ISB", "groodsuntay"),
  degrees = TRUE,
  signed = FALSE,
  plane_normal = NULL
)
```

## Arguments

- pe:

  A `PhysioExperiment` object with position assays (`position_x`,
  `position_y`, and optionally `position_z`).

- joints:

  A named list of joint definitions. For `"3point"`, each element is a
  list with components `proximal`, `joint`, and `distal` (marker column
  names). For `"groodsuntay"` / `"ISB"`, each element is a list with
  `proximal` and `distal` *segment* specs, each itself a list of
  `proximal`/`distal`/`lateral` marker names (see
  [`jointCoordinateSystem()`](https://x-biosignal.github.io/PhysioMoCap/reference/jointCoordinateSystem.md)).

- convention:

  Angle convention: `"3point"` (unsigned angle at the vertex, the
  default) or `"groodsuntay"` / `"ISB"` (signed 3-DOF flexion,
  ab/adduction and internal/external rotation from anatomical segment
  frames).

- degrees:

  Logical. If `TRUE` (default), return angles in degrees. If `FALSE`,
  return angles in radians.

- signed:

  Logical, `"3point"` only. If `FALSE` (default) the vertex angle is the
  unsigned \\\[0, 180\]\\ included angle. If `TRUE` the angle carries
  the sign of the rotation from the proximal to the distal vector about
  `plane_normal`, which separates flexion from hyperextension (see
  Details).

- plane_normal:

  The axis the signed angle is measured about, used only when
  `signed = TRUE`. Either `NULL` (the default: the global z axis for 2D
  data, or a best-fit plane normal derived from the data for 3D data), a
  length-3 numeric vector, an `n_frames x 3` matrix of per-frame
  normals, or a named list giving any of those per joint.

## Value

A `PhysioExperiment` with a `"joint_angles"` assay. For `"3point"` this
is `n_frames x n_joints` (one angle per joint: unsigned in \\\[0,
180\]\\, or signed in \\(-180, 180\]\\ when `signed = TRUE`). For
`"groodsuntay"` / `"ISB"` it is `n_frames x (3 * n_joints)`: three
columns per joint (`<joint>_flexion`, `<joint>_abduction`,
`<joint>_rotation`) with `colData` carrying the `joint` and `axis`
labels.

## Details

For the `"3point"` convention, the angle is computed at the vertex
(joint point) between the proximal-to-joint and distal-to-joint
direction vectors:

\$\$\theta = \arccos\left(\frac{v_1 \cdot v_2}{\|v_1\|
\|v_2\|}\right)\$\$

where \\v_1 = \text{proximal} - \text{joint}\\ and \\v_2 =
\text{distal} - \text{joint}\\.

The result is clamped to \\\[0, \pi\]\\ (or \\\[0, 180\]\\ in degrees).
If any of the three points contain `NA` for a given frame, the angle for
that frame is `NA`.

## Signed vertex angles

The unsigned vertex angle cannot tell flexion from hyperextension: a
knee flexed 10 degrees and a knee hyperextended 10 degrees both give an
included angle of 170 degrees, because \\\arccos\\ discards which side
of the proximal segment the distal segment lies on. With `signed = TRUE`
the angle is instead

\$\$\theta = \mathrm{atan2}\left((v_1' \times v_2') \cdot \hat{n},\\
v_1' \cdot v_2'\right)\$\$

where \\\hat{n}\\ is the unit `plane_normal` and \\v_i'\\ is \\v_i\\
with its \\\hat{n}\\ component removed. The magnitude is the same
included angle as before whenever the three points lie in the plane; the
sign is positive when the rotation from \\v_1\\ to \\v_2\\ follows the
right-hand rule about \\\hat{n}\\, and flips when the distal segment
crosses to the other side of the proximal segment. Choose (or negate)
`plane_normal` so that this direction is flexion, giving the clinical
flexion(+) / extension(-) convention; the corresponding deviation from
the straight (anatomically neutral) position is `180 - abs(theta)`.

Because the range is \\(-180, 180\]\\, the signed angle wraps at exactly
the straight configuration - the pose whose two sides the sign is there
to tell apart. A joint that moves through full extension therefore steps
from `+180` to `-180`, and differentiating that series directly gives a
spurious spike. Work with `180 - abs(theta)` (which is continuous
through the neutral pose) or unwrap the series before differentiating.

For 2D data (no `position_z` assay) the default normal is the global z
axis, so a positive angle means the distal vector is counter-clockwise
from the proximal vector in the x-y plane. For 3D data with
`plane_normal = NULL` the normal is the least-variance direction of the
two joint vectors over all frames (a best-fit plane), which is only
defined up to a global flip; the function warns in that case because the
flexion(+) direction is then a property of the data rather than a
clinical convention. Because \\v_i\\ is projected onto the plane,
out-of-plane motion makes the signed magnitude smaller than the unsigned
3D angle; the two agree exactly for planar motion.

For `"groodsuntay"` / `"ISB"`, a proximal and distal anatomical frame
are built for each joint (via
[`jointCoordinateSystem()`](https://x-biosignal.github.io/PhysioMoCap/reference/jointCoordinateSystem.md))
and the three signed angles are extracted with
[`groodSuntayAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/groodSuntayAngles.md).
This is a *sequence- dependent* Grood-Suntay floating-axis (Z-X-Y
Cardan) decomposition: flexion (about the proximal medio-lateral axis)
is extracted first and internal/ external rotation (about the distal
long axis) last.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions: application to the knee."
Journal of Biomechanical Engineering, 105(2), 136-144.

## See also

[`vectorAngle()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorAngle.md),
[`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md),
[`eulerToQuaternion()`](https://x-biosignal.github.io/PhysioMoCap/reference/eulerToQuaternion.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readTRC("markers.trc")
joints <- list(
  right_elbow = list(
    proximal = "RShoulder",
    joint    = "RElbow",
    distal   = "RWrist"
  ),
  right_knee = list(
    proximal = "RHip",
    joint    = "RKnee",
    distal   = "RAnkle"
  )
)
pe_angles <- calculateJointAngles(pe, joints)
SummarizedExperiment::assay(pe_angles, "joint_angles")

# Signed sagittal angles: flexion and hyperextension get opposite signs
pe_signed <- calculateJointAngles(pe, joints, signed = TRUE,
                                  plane_normal = c(0, 0, 1))
} # }
```
