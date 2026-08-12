# Posturographic center-of-pressure sway metrics (Prieto 1996)

Computes the full Prieto et al. (1996) battery of postural-steadiness
measures from a center-of-pressure (CoP) time series, together with the
non-linear complexity descriptors used by
[schema_balance](https://x-biosignal.github.io/PhysioMoCap/reference/schema_balance.md).
Distances are reported in the units of the supplied CoP (typically mm or
m); frequencies in Hz; areas in CoP-units squared; velocities in
CoP-units per second.

## Usage

``` r
swayMetrics(
  cop,
  sampling_rate,
  ap = NULL,
  ml = NULL,
  detrend = c("mean", "none"),
  entropy = TRUE,
  m = 2L,
  r = 0.2,
  base_of_support = NULL
)
```

## Arguments

- cop:

  Center-of-pressure data. A `data.frame` from
  [`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md)
  (columns `cop_x` = ML, `cop_y` = AP), a two-column matrix/`data.frame`
  (columns interpreted as `ml`, `ap` unless named), or `NULL` when
  supplying `ap`/`ml` directly.

- sampling_rate:

  Sampling rate in Hz.

- ap, ml:

  Optional anteroposterior / mediolateral CoP vectors (override `cop`).

- detrend:

  Either `"mean"` (subtract the mean CoP, the Prieto convention) or
  `"none"`.

- entropy:

  Logical; compute per-axis
  [`sampleEntropy()`](https://x-biosignal.github.io/PhysioMoCap/reference/sampleEntropy.md)
  and DFA-\\\alpha\\ (default `TRUE`).

- m, r:

  Sample-entropy embedding dimension and tolerance (tolerance is a
  fraction of each axis SD).

- base_of_support:

  Optional numeric `c(ap = , ml = )` giving the half extent of the base
  of support (in CoP units) about the mean CoP, used for
  time-to-boundary. `NULL` (default) returns `NA` for the TTB measures.

## Value

A `sway_metrics` object (a named list) with the Prieto measures and, in
`$metrics`, a one-row `data.frame` aligned to the
[schema_balance](https://x-biosignal.github.io/PhysioMoCap/reference/schema_balance.md)
metric names.

## Details

The measures are defined relative to the mean CoP. With \\RD_n\\ the
resultant distance of sample \\n\\ from the mean CoP and \\T\\ the trial
duration:

- **Path length** (total excursion, TOTEX): the summed point-to-point
  distance; **mean velocity** is TOTEX / T.

- **RMS distance** (RDIST) and **mean distance** (MDIST), resultant and
  per-axis.

- **95% confidence circle area** (AREA-CC) \\= \pi (MDIST + z\\
  s\_{RD})^2\\ with \\z = 1.645\\.

- **95% confidence ellipse area** (AREA-CE) \\= 2\pi F\_{0.05\[2,n-2\]}
  \sqrt{s\_{AP}^2 s\_{ML}^2 - s\_{AP,ML}^2}\\.

- **Sway area** (AREA-SW), area swept per unit time.

- **Mean frequency** (MFREQ), the equivalent rotational frequency
  \\MVELO / (2\pi\\ MDIST)\\.

- **Fractal dimension** (FD-CC) and frequency-domain measures (total
  power, 50%/95% power frequency, centroidal frequency, frequency
  dispersion).

- **Non-linear** sample entropy and DFA-\\\alpha\\ per axis, and
  optional time-to-boundary if a base of support is supplied.

## References

Prieto TE, Myklebust JB, Hoffmann RG, Lovett EG, Myklebust BM (1996).
"Measures of postural steadiness." IEEE Trans Biomed Eng 43(9):956-966.

## See also

[`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md),
[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md),
[`stabilogramDiffusion()`](https://x-biosignal.github.io/PhysioMoCap/reference/stabilogramDiffusion.md),
[`sensoryOrganizationTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/sensoryOrganizationTest.md),
[schema_balance](https://x-biosignal.github.io/PhysioMoCap/reference/schema_balance.md)

## Examples

``` r
t <- seq(0, 30, by = 0.01)
cop <- data.frame(cop_x = 2 * sin(2 * pi * 0.2 * t),
                  cop_y = 3 * cos(2 * pi * 0.2 * t))
sm <- swayMetrics(cop, sampling_rate = 100)
sm$path_length
#> [1] 95.19201
sm$mean_velocity
#> [1] 3.173067
```
