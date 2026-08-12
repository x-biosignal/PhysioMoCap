# Count reaching movement units

Counts accepted speed peaks as movement units (submovements). A peak
must exceed both a relative height threshold and a relative prominence
threshold.

## Usage

``` r
movementUnits(
  speed,
  fs = NULL,
  height_frac = 0.05,
  prominence_frac = 0.1,
  min_peak_distance = NULL
)
```

## Arguments

- speed:

  Numeric non-negative tangential-speed profile.

- fs:

  Optional sampling frequency in Hz. Required only when
  `min_peak_distance` is supplied.

- height_frac:

  Peak-height threshold as a fraction of maximum speed.

- prominence_frac:

  Minimum peak prominence as a fraction of maximum speed.

- min_peak_distance:

  Optional minimum inter-peak interval in seconds.

## Value

Integer movement-unit count. Accepted 1-based peak indices are stored in
the `"peaks"` attribute.

## References

Rohrer B, Fasoli S, Krebs HI, et al. (2002). Movement smoothness changes
during stroke recovery. *Journal of Neuroscience*, 22:8297-8304.

## Examples

``` r
t <- seq(0, 1, length.out = 500)
speed <- exp(-((t - 0.3) / 0.04)^2) + exp(-((t - 0.7) / 0.04)^2)
movementUnits(speed)
#> [1] 2
#> attr(,"peaks")
#> [1] 151 350
```
