# Align EMG to motion-capture sampling grid

Align EMG to motion-capture sampling grid

## Usage

``` r
alignEMGtoMoCap(
  emg,
  emg_sampling_rate,
  mocap_length,
  mocap_sampling_rate,
  method = "linear"
)
```

## Arguments

- emg:

  Numeric vector or matrix of EMG data (time x channels).

- emg_sampling_rate:

  EMG sampling rate (Hz).

- mocap_length:

  Target number of MoCap samples.

- mocap_sampling_rate:

  Target MoCap sampling rate (Hz).

- method:

  Interpolation method passed to
  [`stats::approx()`](https://rdrr.io/r/stats/approxfun.html).

## Value

Matrix of aligned EMG data with `mocap_length` rows.

## References

Merletti R, Parker PA (2004). "Electromyography: Physiology,
Engineering, and Non-Invasive Applications." IEEE Press/Wiley.

## See also

[`integrateEMGMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/integrateEMGMoCap.md)
for full EMG-MoCap integration,
[`resampleSignal()`](https://x-biosignal.github.io/PhysioMoCap/reference/resampleSignal.md)
for general signal resampling.

## Examples

``` r
emg <- matrix(rnorm(2000), ncol = 2)
emg_aligned <- alignEMGtoMoCap(emg, 1000, mocap_length = 200,
                               mocap_sampling_rate = 100)
```
