# Gait Deviation Index (Schwartz & Rozumalski 2008)

Scores overall gait pathology on a scale where the normative control
population averages 100 with a standard deviation of 10 (by
construction); values below 100 indicate greater deviation, each 10
points corresponding to one standard deviation. The subject's nine
kinematic curves are projected onto the normative feature basis, and the
log of the distance to the control mean is standardised against the
control distribution.

## Usage

``` r
gaitDeviationIndex(kinematics, norm = NULL, basis = NULL, n_features = 15L)
```

## Arguments

- kinematics:

  Subject kinematics (see
  [`gaitVariableScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitVariableScore.md));
  curves are time-normalised to the basis's point count (typically 51).

- norm:

  A `gait_norm` reference (from
  [`PhysioGaitNorm::loadGaitNorm()`](https://x-biosignal.github.io/PhysioGaitNorm//reference/loadGaitNorm.html));
  if `NULL`, loaded from PhysioGaitNorm. Ignored when `basis` is
  supplied.

- basis:

  An optional precomputed
  [`gdiBasis()`](https://x-biosignal.github.io/PhysioMoCap/reference/gdiBasis.md)
  (reuse across many subjects); if `NULL` it is built from `norm`.

- n_features:

  Number of gait features when building the basis (default 15).

## Value

A `gait_deviation_index` object: a list with `gdi` (numeric),
`distance`, `z`, and `n_features`.

## References

Schwartz MH, Rozumalski A (2008). Gait & Posture 28(3):351-357.

## See also

[`gdiBasis()`](https://x-biosignal.github.io/PhysioMoCap/reference/gdiBasis.md),
[`gaitProfileScore()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitProfileScore.md)
