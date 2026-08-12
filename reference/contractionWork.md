# Angular work and impulse for strength-test repetitions

Integrates torque over time to obtain angular impulse and, when angle or
angular velocity is available, integrates torque over angular
displacement to obtain mechanical work.

## Usage

``` r
contractionWork(
  torque,
  sampling_rate,
  angle = NULL,
  angular_velocity = NULL,
  reps = NULL,
  onset_threshold = 7.5,
  body_mass = NULL
)
```

## Arguments

- torque:

  Numeric torque trace in N m.

- sampling_rate:

  Sampling rate in Hz.

- angle:

  Optional angle trace in degrees.

- angular_velocity:

  Optional angular-velocity trace in degrees/s, used when `angle` is not
  supplied.

- reps:

  Optional named list of strictly increasing integer sample-index
  vectors. When `NULL`, repetitions are segmented with
  [`computeImpulse()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeImpulse.md).

- onset_threshold:

  Non-negative torque threshold used for automatic repetition
  segmentation.

- body_mass:

  Optional positive body mass in kg.

## Value

A `contraction_work` data frame with angular impulse (N m s), work (J),
and optional mass-normalised values for each repetition.

## References

Winter DA (2009). *Biomechanics and Motor Control of Human Movement*.
4th ed. John Wiley & Sons.

## Examples

``` r
torque <- c(seq(0, 100, length.out = 51), seq(98, 0, length.out = 50))
contractionWork(torque, sampling_rate = 100,
                reps = list(rep1 = seq_along(torque)))
#> <contraction_work> 1 repetition(s) at 100 Hz
#>   rep onset_index offset_index angular_impulse work
#>  rep1           1          101              50   NA
```
