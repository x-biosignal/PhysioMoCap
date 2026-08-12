# Label joint power bursts with Winter nomenclature

Segments a single-gait-cycle joint power time series into contiguous
same-sign bursts and assigns Winter's power-phase labels: `A1`/`A2` for
the ankle, `H1`-`H3` for the hip, and `K1`-`K4` for the knee. Each
canonical burst has an expected sign (generation vs absorption) and an
approximate location within the gait cycle; detected bursts are matched
to the nearest unused canonical burst of the same sign.

## Usage

``` r
labelPowerBursts(
  power,
  sampling_rate,
  joint = c("ankle", "knee", "hip"),
  body_mass = NULL
)
```

## Arguments

- power:

  Numeric vector of joint power (W) over one gait cycle, or a data frame
  with a `power` column.

- sampling_rate:

  Sampling rate in Hz.

- joint:

  One of `"ankle"`, `"knee"`, or `"hip"`.

- body_mass:

  Optional body mass in kilograms; if supplied, a `work_per_kg` column
  (J/kg) is added.

## Value

A data frame (class `power_bursts`) with one row per detected burst:
`label` (canonical burst name or `NA` if unmatched), `joint`, `type`
(`"generation"` or `"absorption"`), `start_pct`, `end_pct`, `peak_power`
(W, signed), and `work` (J), ordered by time.

## Details

The `power` vector is assumed to span exactly one gait cycle (initial
contact to the next ipsilateral initial contact), so burst timing is
reported as a percentage of the cycle.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons. Power-phase nomenclature A1-A2 / H1-H3 /
K1-K4.

## See also

[`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md),
[`jointWork()`](https://x-biosignal.github.io/PhysioMoCap/reference/jointWork.md).

## Examples

``` r
t <- seq(0, 1, length.out = 101)
ankle_power <- ifelse(t < 0.4, -50 * sin(pi * t / 0.4),
                      120 * sin(pi * (t - 0.4) / 0.2) * (t < 0.6))
labelPowerBursts(ankle_power, sampling_rate = 100, joint = "ankle")
#>   label joint       type start_pct end_pct peak_power      work
#> 1    A1 ankle absorption         1      39        -50 -12.72585
#> 2    A2 ankle generation        41      59        120  15.24745
```
