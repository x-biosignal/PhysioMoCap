# Log Dimensionless Jerk (LDLJ) movement smoothness

The log of the (speed-based) dimensionless jerk, negated so that more
negative = less smooth.

## Usage

``` r
ldlj(speed, fs)
```

## Arguments

- speed:

  Numeric speed profile.

- fs:

  Sampling frequency in Hz.

## Value

The LDLJ (negative scalar).

## References

Balasubramanian et al. (2015); Melendez-Calderon et al. (2021).

## Examples

``` r
t <- seq(0, 1, length.out = 200); tau <- t
speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4
ldlj(speed, fs = 200)
#> [1] -5.311984
```
