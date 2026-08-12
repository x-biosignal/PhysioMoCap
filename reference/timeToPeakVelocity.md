# Time to peak reaching velocity

Time to peak reaching velocity

## Usage

``` r
timeToPeakVelocity(
  speed,
  fs,
  onset_threshold = 0.05,
  threshold_type = c("relative", "absolute"),
  normalize = FALSE
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

- normalize:

  Logical; return time-to-peak divided by movement time instead of
  seconds.

## Value

Time from detected onset to peak speed in seconds, or a unitless
fraction of movement time when `normalize = TRUE`.

## Examples

``` r
speed <- c(rep(0, 20), seq(0, 1, length.out = 30),
           seq(1, 0, length.out = 30), rep(0, 20))
timeToPeakVelocity(speed, fs = 100)
#> [1] 0.27
```
