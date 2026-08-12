# Differentiate a numeric vector or matrix

Low-level function to compute numerical derivatives of arbitrary order
using finite difference methods.

## Usage

``` r
differentiate(x, dt, method = c("central", "forward", "backward"), order = 1L)
```

## Arguments

- x:

  Numeric vector or matrix (time x channels).

- dt:

  Time step between samples (1 / sampling_rate).

- method:

  Difference method: "central", "forward", or "backward".

- order:

  Derivative order: 1 (velocity), 2 (acceleration), or 3 (jerk).

## Value

Differentiated data with same dimensions as input. Boundary values where
the stencil cannot be applied are set to NA.

## Details

For `method = "central"` with `order = 1`: \$\$f'(i) = (x\[i+1\] -
x\[i-1\]) / (2 \cdot dt)\$\$

For `method = "central"` with `order = 2`: \$\$f''(i) = (x\[i+1\] - 2
x\[i\] + x\[i-1\]) / dt^2\$\$

For higher orders, the derivative is computed by repeated application of
the first-order formula.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
for computing velocity from PhysioExperiment,
[`computeAcceleration()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeAcceleration.md)
for second-order derivatives,
[`savgolFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/savgolFilter.md)
for smoothed differentiation via Savitzky-Golay.

## Examples

``` r
# Differentiate sin to get cos
t <- seq(0, 2 * pi, length.out = 200)
x <- sin(t)
dx <- differentiate(x, dt = t[2] - t[1], method = "central", order = 1)
# dx should approximate cos(t)
```
