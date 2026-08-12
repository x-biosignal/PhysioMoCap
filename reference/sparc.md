# Spectral Arc Length (SPARC) movement smoothness

A duration- and amplitude-robust smoothness measure computed from the
normalized Fourier magnitude spectrum of a speed profile. More negative
= less smooth. A smooth minimum-jerk movement is approximately -1.4.

## Usage

``` r
sparc(speed, fs, padlevel = 4, fc = 10, amp_th = 0.05)
```

## Arguments

- speed:

  Numeric speed (tangential velocity magnitude) profile.

- fs:

  Sampling frequency in Hz.

- padlevel:

  Zero-padding exponent added to the FFT length (default 4).

- fc:

  Maximum cutoff frequency in Hz (default 10).

- amp_th:

  Normalized amplitude threshold for the adaptive cutoff (0.05).

## Value

The spectral arc length (negative scalar); `NA` if undefined.

## References

Balasubramanian S, Melendez-Calderon A, Roby-Brami A, Burdet E (2015).
"On the analysis of movement smoothness." J NeuroEng Rehabil 12:112.

## Examples

``` r
t <- seq(0, 1, length.out = 200); tau <- t
speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4  # minimum-jerk speed
sparc(speed, fs = 200)
#> [1] -1.403567
```
