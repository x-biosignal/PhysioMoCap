# Compute moving RMS envelope of EMG

Compute moving RMS envelope of EMG

## Usage

``` r
computeRMSEnvelope(x, window_samples = 50L, center = TRUE)
```

## Arguments

- x:

  Numeric vector or matrix (time x channels).

- window_samples:

  Window length in samples.

- center:

  Logical; if `TRUE`, uses centered window.

## Value

RMS envelope with the same dimensions as `x`.

## References

Merletti R, Parker PA (2004). "Electromyography: Physiology,
Engineering, and Non-Invasive Applications." IEEE Press/Wiley.

## See also

[`rectifyEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/rectifyEMG.md)
for signal rectification,
[`normalizeEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeEMG.md)
for MVC or peak normalization,
[`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
for complete EMG processing pipeline.

## Examples

``` r
set.seed(1)
sig <- rnorm(1000)
env <- computeRMSEnvelope(sig, window_samples = 50)
```
