# Rectify EMG signals

Rectify EMG signals

## Usage

``` r
rectifyEMG(x, method = c("fullwave", "halfwave"))
```

## Arguments

- x:

  Numeric vector or matrix (time x channels).

- method:

  Rectification method: `"fullwave"` or `"halfwave"`.

## Value

Rectified signal with the same dimensions as `x`.

## References

Merletti R, Parker PA (2004). "Electromyography: Physiology,
Engineering, and Non-Invasive Applications." IEEE Press/Wiley.

## See also

[`computeRMSEnvelope()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeRMSEnvelope.md)
for computing RMS envelope,
[`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
for complete EMG processing pipeline.

## Examples

``` r
x <- c(-1, -0.5, 0, 0.5, 1)
rectifyEMG(x, method = "fullwave")
#> [1] 1.0 0.5 0.0 0.5 1.0
```
