# ZUPT-aided strapdown integration of world-frame acceleration

Double-integrates world-frame linear acceleration to velocity and
position, applying a zero-velocity update (ZUPT) at each stance sample:
the integrated velocity is de-drifted so that it returns to zero at
every stance sample (linear de-drifting within each swing), which bounds
the per-stride integration drift.

## Usage

``` r
strapdownIntegrate(accel_world, sampling_rate, stance)
```

## Arguments

- accel_world:

  Numeric matrix (n x 3) of gravity-free acceleration in the world frame
  (m/s^2), e.g. from
  [`removeGravity()`](https://x-biosignal.github.io/PhysioMoCap/reference/removeGravity.md)
  rotated into world axes.

- sampling_rate:

  Sampling rate in Hz.

- stance:

  Logical vector of length `n`, `TRUE` at stance samples (from
  [`detectStanceZUPT()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStanceZUPT.md)).

## Value

A list with numeric matrices `velocity` and `position` (each n x 3).

## References

Mariani B, Hoskovec C, Rochat S, Bula C, Penders J, Aminian K (2010).
"3D gait assessment in young and elderly subjects using foot-worn
inertial sensors." J Biomech 43(15):2999-3006.

## See also

[`detectStanceZUPT()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectStanceZUPT.md),
[`footImuGait()`](https://x-biosignal.github.io/PhysioMoCap/reference/footImuGait.md).

## Examples

``` r
stance <- rep(c(TRUE, FALSE, TRUE, FALSE, TRUE), c(60, 40, 60, 40, 60))
accel_world <- matrix(0, length(stance), 3)
si <- strapdownIntegrate(accel_world, sampling_rate = 200, stance = stance)
names(si)
#> [1] "velocity" "position"
```
