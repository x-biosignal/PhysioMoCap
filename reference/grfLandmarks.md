# Extract stance-phase landmarks from a time-normalised vertical GRF curve

From a vertical ground-reaction-force curve time-normalised to the
stance phase (0-100 %), reads the three classic landmarks of the
double-humped stance profile: the loading (weight-acceptance) peak, the
mid-stance trough, and the push-off peak. Applied to a
body-weight-normalised curve, the landmarks are directly comparable
across subjects of different mass, and the peak-trough-peak pattern is
the mechanical signature clinical gait analyses contrast between cohorts
(e.g. reduced weight-acceptance modulation in pathological gait: lower
peaks, a raised trough).

## Usage

``` r
grfLandmarks(
  grf,
  loading_window = 5:40,
  midstance_window = 30:60,
  pushoff_window = 45:80
)
```

## Arguments

- grf:

  Numeric vector: a vertical GRF curve time-normalised to the stance
  phase (e.g. 101 points spanning 0-100 %). Usually in body-weight units
  so the landmarks are subject-mass independent. A matrix (curves x
  time) is also accepted, in which case the landmarks are read from the
  ensemble-mean curve (`colMeans`) — the group-mean landmarks of a
  cohort of stance curves.

- loading_window, midstance_window, pushoff_window:

  Integer index ranges (into `grf`) in which to read the loading peak (a
  maximum), the mid-stance trough (a minimum) and the push-off peak (a
  maximum). Defaults target a 101-point stance curve; widen them for
  populations with atypical timing.

## Value

A named numeric vector `c(peak1, trough, peak2)` — the loading peak, the
mid-stance trough and the push-off peak, in the units of `grf`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

Horsak B, Slijepcevic D, Raberger AM, Schwab C, Worisch M, Zeppelzauer M
(2020). "GaitRec, a large-scale ground reaction force dataset of healthy
and impaired gait." Scientific Data 7:143.

## See also

[`filterGRF()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterGRF.md)
to band-limit the force trace,
[`computeImpulse()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeImpulse.md)
and
[`computeLoadingRate()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeLoadingRate.md)
for other GRF-derived measures.

## Examples

``` r
# a synthetic double-humped stance curve (101 pts, body-weight units)
g <- 1.1 * sin(seq(0, pi, length.out = 101))^0.5
g[46:56] <- g[46:56] * 0.68
grfLandmarks(g)
#>     peak1    trough     peak2 
#> 1.0669891 0.7433812 1.0902145 
```
