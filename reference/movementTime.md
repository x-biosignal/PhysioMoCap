# Reaching movement time

Reaching movement time

## Usage

``` r
movementTime(
  speed,
  fs,
  onset_threshold = 0.05,
  threshold_type = c("relative", "absolute")
)
```

## Arguments

- speed:

  Numeric non-negative tangential-speed profile.

- fs:

  Sampling frequency in Hz.

- onset_threshold:

  Non-negative threshold, interpreted according to `threshold_type`.

- threshold_type:

  `"relative"` for a fraction of peak speed or `"absolute"` for speed
  units.

## Value

Movement duration in seconds. The 1-based onset and offset samples are
stored as attributes. Returns `NA` when no sample exceeds threshold.

## Examples

``` r
speed <- c(rep(0, 20), seq(0, 1, length.out = 30),
           seq(1, 0, length.out = 30), rep(0, 20))
movementTime(speed, fs = 100)
#> [1] 0.55
#> attr(,"onset")
#> [1] 23
#> attr(,"offset")
#> [1] 78
```
