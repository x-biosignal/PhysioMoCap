# Build a Gait Deviation Index feature basis from a normative reference

Computes the singular-value-decomposition feature basis of the normative
feature population used to score the Gait Deviation Index (Schwartz &
Rozumalski 2008), together with the control-population log-distance mean
and standard deviation used to standardise the index.

## Usage

``` r
gdiBasis(norm = NULL, n_features = 15L)
```

## Arguments

- norm:

  A `gait_norm` reference with a `features` matrix (subjects x
  concatenated kinematics); if `NULL`, loaded from PhysioGaitNorm.

- n_features:

  Number of singular vectors (gait features) to retain (default 15).

## Value

A `gdi_basis` object.

## References

Schwartz MH, Rozumalski A (2008). Gait & Posture 28(3):351-357.

## See also

[`gaitDeviationIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/gaitDeviationIndex.md)
