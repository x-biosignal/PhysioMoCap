# Cerebral-palsy gait pipeline (GDI + pathology flags)

Computes the Gait Deviation Index (Schwartz & Rozumalski 2008) for a
subject's kinematics, categorises it, adds the kinematic pathology flags
detectable from the same waveforms (stiff knee, Trendelenburg), and
records the GMFCS level for stratified interpretation.

## Usage

``` r
pipelineCPgait(kinematics, norm = NULL, gmfcs = NULL)
```

## Arguments

- kinematics:

  Subject kinematics passed to
  [`gaitDeviationIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitDeviationIndex.md)
  (a variables x cycle-points matrix with row names matching the norm).

- norm:

  A `gait_norm` reference (from
  [`PhysioGaitNorm::loadGaitNorm()`](https://x-biosignal.github.io/PhysioGaitNorm//reference/loadGaitNorm.html));
  if `NULL`, the default is loaded from PhysioGaitNorm.

- gmfcs:

  Optional Gross Motor Function Classification System level (I-V).

## Value

A `cp_gait_report` object.

## References

Schwartz & Rozumalski (2008); Palisano et al. (1997) GMFCS.

## See also

[`gaitDeviationIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitDeviationIndex.md),
[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md)
