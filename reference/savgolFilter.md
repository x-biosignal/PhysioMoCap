# Savitzky-Golay filter for smoothing and differentiation

Pure R implementation of the Savitzky-Golay filter using local
polynomial fitting. Useful for smoothing noisy signals while preserving
features like peak height and width better than simple moving averages.

## Usage

``` r
savgolFilter(x, window_length = 11, poly_order = 3, deriv = 0)
```

## Arguments

- x:

  A numeric vector or matrix (time x channels).

- window_length:

  Window length for the filter. Must be a positive odd integer.

- poly_order:

  Polynomial order for local fitting (must be less than
  `window_length`).

- deriv:

  Derivative order. 0 for smoothing, 1 for first derivative, 2 for
  second derivative, etc.

## Value

Filtered/smoothed data with the same dimensions as `x`.

## Details

The Savitzky-Golay filter fits a local polynomial of degree `poly_order`
to a window of `window_length` points, using least-squares. The filter
coefficients are computed analytically and applied via convolution.

For differentiation (`deriv > 0`), the result is the derivative of the
fitted polynomial, which provides a smooth estimate of the derivative.

Edge handling: the first and last `floor(window_length/2)` points are
computed with truncated windows where possible, or set to NA.

## References

Savitzky A, Golay MJE (1964). "Smoothing and Differentiation of Data by
Simplified Least Squares Procedures." Analytical Chemistry, 36(8),
1627-1639.

## See also

[`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md)
for frequency-domain Butterworth filtering,
[`movingAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/movingAverage.md)
for simple moving average smoothing,
[`differentiate()`](https://x-biosignal.github.io/PhysioMoCap/reference/differentiate.md)
for numerical differentiation.

## Examples

``` r
# Smooth a noisy sine wave
t <- seq(0, 2 * pi, length.out = 200)
x <- sin(t) + rnorm(200, sd = 0.2)
x_smooth <- savgolFilter(x, window_length = 11, poly_order = 3)

# Compute first derivative
dx <- savgolFilter(x, window_length = 11, poly_order = 3, deriv = 1)
```
