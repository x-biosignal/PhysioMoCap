# Integrate joint power into concentric and eccentric work

Integrates a joint power time series (from
[`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md))
with the trapezoidal rule to obtain concentric work (integral of
positive "generation" power) and eccentric work (integral of negative
"absorption" power). Because the trapezoidal rule is linear in the
sampled values, `concentric_work + eccentric_work` equals the net
integrated work to floating-point precision. Work can optionally be
split per gait cycle or movement phase and normalised to body mass.

## Usage

``` r
jointWork(power, sampling_rate, body_mass = NULL, windows = NULL)
```

## Arguments

- power:

  Numeric vector of joint power (W), or a data frame with a `power`
  column as returned by `computeJointPower(..., split = TRUE)`.

- sampling_rate:

  Sampling rate in Hz.

- body_mass:

  Optional body mass in kilograms; if supplied, mass-normalised work
  columns (`*_per_kg`, J/kg) are added.

- windows:

  Optional named list of integer index vectors, each selecting the
  samples of one gait cycle or phase (e.g. from
  [`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)).
  Work is computed independently within each window. If `NULL`, work is
  computed over the whole series (window label `"full"`).

## Value

A data frame (class `joint_work`) with one row per window and columns
`window`, `concentric_work`, `eccentric_work`, and `net_work` (J), plus
the mass-normalised counterparts when `body_mass` is given.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md),
[`labelPowerBursts()`](https://x-biosignal.github.io/PhysioMoCap/reference/labelPowerBursts.md).

## Examples

``` r
t <- seq(0, 1, length.out = 101)
power <- 100 * sin(2 * pi * t)
jointWork(power, sampling_rate = 100, body_mass = 70)
#>   window concentric_work eccentric_work     net_work concentric_work_per_kg
#> 1   full        31.82052      -31.82052 2.220446e-16              0.4545788
#>   eccentric_work_per_kg net_work_per_kg
#> 1            -0.4545788    3.172066e-18
```
