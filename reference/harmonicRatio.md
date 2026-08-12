# Harmonic ratio of a trunk-acceleration signal

The harmonic ratio quantifies the smoothness/rhythmicity of trunk
acceleration over a stride from its Fourier series: because there are
two steps per stride, the even harmonics carry the
step-to-step-symmetric (in-phase) content and the odd harmonics the
asymmetric content. For anterior-posterior and vertical acceleration the
ratio is even/odd (higher = smoother); for medio-lateral it is odd/even
(Menz et al. 2003; Bellanca et al. 2013).

## Usage

``` r
harmonicRatio(
  signal,
  n_strides = 1L,
  direction = c("AP", "vertical", "ML"),
  n_harmonics = 20L
)
```

## Arguments

- signal:

  Numeric acceleration over an integer number of strides (a single
  stride if `n_strides = 1`).

- n_strides:

  Number of strides spanned by `signal` (default 1); the Fourier
  fundamental is the stride frequency.

- direction:

  `"AP"`/`"vertical"` (even/odd) or `"ML"` (odd/even).

- n_harmonics:

  Number of harmonics summed (default 20).

## Value

A `harmonic_ratio` object with `ratio`, `even_sum`, `odd_sum` and
`direction`.

## References

Menz HB, et al. (2003); Bellanca JL, et al. (2013).

## See also

[`maxLyapunovExponent()`](https://x-biosignal.github.io/PhysioMoCap/reference/maxLyapunovExponent.md)

## Examples

``` r
t <- seq(0, 1, length.out = 200)[-200]
# a clean 2-steps-per-stride (even-harmonic) signal
harmonicRatio(cos(2 * 2 * pi * t), direction = "AP")
#> <harmonic_ratio> (AP) ratio = 672942401973048.500 (even=99.5, odd=1.48e-13)
```
