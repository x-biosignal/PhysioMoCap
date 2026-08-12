# Build embedded anatomical segment coordinate systems from marker clusters

Constructs a per-frame right-handed orthonormal coordinate system for
each named body segment (e.g. pelvis, thigh/femur, shank/tibia, foot)
from three markers: a proximal end, a distal end, and a lateral marker.
The axes are `X` (antero-posterior), `Y` (long axis, pointing
proximally) and `Z` (medio-lateral). These segment frames are the input
to
[`groodSuntayAngles`](https://x-biosignal.github.io/PhysioMoCap/reference/groodSuntayAngles.md)
and to the Grood-Suntay / ISB conventions of
[`calculateJointAngles`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md).

## Usage

``` r
jointCoordinateSystem(pe, segments)
```

## Arguments

- pe:

  A `PhysioExperiment` with `"position_x"`, `"position_y"` and
  `"position_z"` assays.

- segments:

  A named list; each element is a list with `proximal`, `distal` and
  `lateral` marker names (columns of the position assays).

## Value

A named list of `n_frames x 3 x 3` arrays (one per segment); for each
the three columns are the X (AP), Y (long) and Z (ML) unit axes.

## References

Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
description of three-dimensional motions." J Biomech Eng, 105(2),
136-144. Wu G, et al. (2002, 2005). "ISB recommendation on definitions
of joint coordinate systems." J Biomech.

## See also

[`groodSuntayAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/groodSuntayAngles.md),
[`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md)

## Examples

``` r
if (FALSE) { # \dontrun{
segs <- list(
  femur = list(proximal = "HIP", distal = "KNEE", lateral = "THIGH"),
  tibia = list(proximal = "KNEE", distal = "ANKLE", lateral = "SHANK"))
frames <- jointCoordinateSystem(pe, segs)
} # }
```
