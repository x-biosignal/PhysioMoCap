# Tardieu score: R1, R2 and the dynamic component

Combines a fast-velocity stretch (the catch angle R1) and a
slow-velocity stretch (the full passive range R2) into the Tardieu
dynamic component `R2 - R1` - the velocity-dependent (spastic) part of
the range, distinct from a fixed contracture.

## Usage

``` r
tardieuScore(fast, slow, sampling_rate = NULL, ...)
```

## Arguments

- fast:

  A
  [`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md)
  result (fast stretch), or a raw fast-stretch angle trace (then scored
  with `onset = "velocity"`).

- slow:

  A
  [`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md)
  result or a raw slow-stretch angle trace; R2 is its end-range angle
  (`rom_max` / `max(angle)`).

- sampling_rate:

  Required only when `fast` is a raw angle trace.

- ...:

  Passed to
  [`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md)
  when `fast` is raw.

## Value

An S3 `tardieu_score` list: `R1`, `R2`, `dynamic_component`.

## See also

[`tardieuStretch()`](https://x-biosignal.github.io/PhysioMoCap/reference/tardieuStretch.md),
[`reflexThreshold()`](https://x-biosignal.github.io/PhysioMoCap/reference/reflexThreshold.md)

## Examples

``` r
fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
fast <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
slow <- 40 * t / 0.6
tardieuScore(tardieuStretch(fast, sampling_rate = fs, onset = "velocity"), slow)
#> Tardieu score: R1 = 25.1 deg, R2 = 40.0 deg, dynamic (R2-R1) = 14.9 deg
```
