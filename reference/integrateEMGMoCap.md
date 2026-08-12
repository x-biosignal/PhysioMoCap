# Integrate EMG and MoCap signals onto a common timeline

Aligns EMG to MoCap sample times and returns a combined table for
downstream feature analysis.

## Usage

``` r
integrateEMGMoCap(
  mocap,
  emg,
  mocap_sampling_rate = NULL,
  emg_sampling_rate,
  mocap_assay = NULL,
  process = TRUE,
  ...
)
```

## Arguments

- mocap:

  A numeric matrix/data.frame (time x features), or a PhysioExperiment
  object.

- emg:

  Numeric vector or matrix (time x channels).

- mocap_sampling_rate:

  MoCap sampling rate in Hz. If `mocap` is a PhysioExperiment and this
  is `NULL`, uses `samplingRate(mocap)`.

- emg_sampling_rate:

  EMG sampling rate in Hz.

- mocap_assay:

  Assay name to use when `mocap` is a PhysioExperiment.

- process:

  Logical; if `TRUE`, runs
  [`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
  before combining.

- ...:

  Additional arguments passed to
  [`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md).

## Value

A list with `mocap`, `emg_aligned`, and `combined` data.frame.

## References

Merletti R, Parker PA (2004). "Electromyography: Physiology,
Engineering, and Non-Invasive Applications." IEEE Press/Wiley.

## See also

[`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
for EMG processing pipeline,
[`alignEMGtoMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/alignEMGtoMoCap.md)
for time-alignment of EMG to MoCap,
[`synchronizeSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/synchronizeSignals.md)
for general multi-signal synchronization.

## Examples

``` r
mocap <- matrix(rnorm(500), ncol = 5)
emg <- matrix(rnorm(5000), ncol = 2)
out <- integrateEMGMoCap(mocap, emg, mocap_sampling_rate = 100,
                         emg_sampling_rate = 1000)
```
