# Movement-smoothness battery (SPARC + LDLJ)

Computes the SPARC and log dimensionless jerk smoothness metrics for a
speed profile. Accepts either a numeric speed vector (with `fs`) or a
`PhysioExperiment`, in which case the speed profile is pulled from the
`assay` (computing it with
[`computeVelocity`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
/
[`computeSpeed`](https://x-biosignal.github.io/PhysioMoCap/reference/computeSpeed.md)
when absent) and the sampling rate from the object. When several markers
are present each is scored.

## Usage

``` r
movementSmoothness(x, fs = NULL, assay = "speed", marker = NULL, ...)
```

## Arguments

- x:

  A numeric speed profile, or a `PhysioExperiment`.

- fs:

  Sampling frequency in Hz (ignored / taken from the object when `x` is
  a `PhysioExperiment`).

- assay:

  Speed assay to use for a `PhysioExperiment` (default `"speed"`).

- marker:

  Optional marker (column) name or index to score; by default all
  markers of the speed assay are scored.

- ...:

  Passed to
  [`sparc`](https://x-biosignal.github.io/PhysioMoCap/reference/sparc.md).

## Value

An S3 `"movement_smoothness"` object: a list with `sparc` and `ldlj`
(named by marker when a `PhysioExperiment` is scored),
`dimensionless_jerk`, `fs` and `n`.

## References

Balasubramanian et al. (2015); Melendez-Calderon et al. (2021).

## Examples

``` r
t <- seq(0, 1, length.out = 200); tau <- t
speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4
movementSmoothness(speed, fs = 200)
#> <movement_smoothness>
#>   samples: 200  |  sampling rate: 200 Hz
#>   SPARC: -1.4036
#>   LDLJ:  -5.3120
```
