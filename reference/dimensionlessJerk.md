# Dimensionless jerk of a speed profile

Dimensionless jerk of a speed profile

## Usage

``` r
dimensionlessJerk(speed, fs)
```

## Arguments

- speed:

  Numeric speed profile.

- fs:

  Sampling frequency in Hz.

## Value

The (positive) dimensionless jerk. See
[`ldlj`](https://x-biosignal.github.io/PhysioMoCap/reference/ldlj.md)
for the log form.

## Examples

``` r
set.seed(1)
speed <- abs(sin(seq(0, pi, length.out = 200))) + 0.01
dimensionlessJerk(speed, fs = 120)
#> [1] 48.46925
```
