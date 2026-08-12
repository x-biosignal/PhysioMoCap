# Process EMG for biomechanics workflows

Applies optional band-pass filtering, rectification, RMS envelope
extraction, optional low-pass smoothing, and optional MVC normalization.

## Usage

``` r
processEMG(
  x,
  sampling_rate,
  bandpass = c(20, 450),
  envelope_cutoff = 6,
  rms_window_ms = 50,
  mvc = NULL,
  filter_method = c("butterworth", "moving_average")
)
```

## Arguments

- x:

  Numeric vector or matrix (time x channels).

- sampling_rate:

  Sampling rate in Hz.

- bandpass:

  Optional length-2 numeric vector (Hz). If `NULL`, no band-pass
  filtering is applied.

- envelope_cutoff:

  Low-pass cutoff (Hz) applied to RMS envelope.

- rms_window_ms:

  RMS window length in milliseconds.

- mvc:

  Optional MVC value(s) for normalization.

- filter_method:

  Filter method used in low-pass steps.

## Value

A list with `filtered`, `rectified`, `envelope`, and (when `mvc` is
provided) `normalized`.

## References

Merletti R, Parker PA (2004). "Electromyography: Physiology,
Engineering, and Non-Invasive Applications." IEEE Press/Wiley.

## See also

[`rectifyEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/rectifyEMG.md)
for signal rectification,
[`computeRMSEnvelope()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeRMSEnvelope.md)
for RMS envelope computation,
[`normalizeEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeEMG.md)
for MVC or peak normalization,
[`integrateEMGMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/integrateEMGMoCap.md)
for EMG-MoCap data integration.

## Examples

``` r
set.seed(1)
emg <- matrix(rnorm(2000), ncol = 2)
out <- processEMG(emg, sampling_rate = 1000)
```
