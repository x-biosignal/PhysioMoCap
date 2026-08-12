# Peak torque from isometric or isokinetic dynamometry

Finds the maximum gravity-corrected torque. For isokinetic trials with
an angular-velocity trace, the search is restricted to samples within
`velocity_tol` of the target velocity so acceleration and deceleration
transients do not determine the peak.

## Usage

``` r
peakTorque(
  torque,
  sampling_rate,
  mode = c("isokinetic", "isometric"),
  angle = NULL,
  angular_velocity = NULL,
  target_velocity = NULL,
  velocity_tol = 0.1,
  at_angle = NULL,
  gravity = NULL
)
```

## Arguments

- torque:

  Numeric torque trace in N m.

- sampling_rate:

  Sampling rate in Hz.

- mode:

  Either `"isokinetic"` or `"isometric"`.

- angle:

  Optional joint-angle trace in degrees.

- angular_velocity:

  Optional angular-velocity trace in degrees/s.

- target_velocity:

  Optional target angular velocity in degrees/s. The largest observed
  absolute velocity is used when omitted.

- velocity_tol:

  Non-negative relative tolerance around target velocity.

- at_angle:

  Optional angles in degrees at which torque is interpolated along the
  rising angular limb.

- gravity:

  Optional scalar or sample-wise gravity torque in N m to subtract
  before analysis.

## Value

A `peak_torque` object containing the peak value, time, sample, angle,
angle-specific values, mode, and searched sample indices.

## References

Aagaard P, Simonsen EB, Andersen JL, Magnusson P, Dyhre-Poulsen P
(2002). Increased rate of force development and neural drive of human
skeletal muscle following resistance training. *Journal of Applied
Physiology*, 93:1318-1326.
[doi:10.1152/japplphysiol.00283.2002](https://doi.org/10.1152/japplphysiol.00283.2002)

## Examples

``` r
torque <- c(seq(0, 120, length.out = 101), rep(120, 50))
peakTorque(torque, sampling_rate = 100, mode = "isometric")
#> <peak_torque> 120.000 N m at 1.000 s (sample 101)
```
