# Integrate EMG and MoCap signals onto a common timeline

Processes EMG at its native sampling rate, then aligns the resulting
envelope (or MVC-normalized envelope) to MoCap sample times for feature
analysis. Start times must be expressed on a shared clock. Alignment
uses linear interpolation with the selected support policy; it does not
estimate offsets. With `process = FALSE`, raw samples are interpolated
without anti-alias filtering. With `outside = "NA"`, combined features
remain missing outside raw-data support even if processing produces
finite values beyond that support.

## Usage

``` r
integrateEMGMoCap(
  mocap,
  emg,
  mocap_sampling_rate = NULL,
  emg_sampling_rate,
  mocap_assay = NULL,
  process = TRUE,
  ...,
  emg_start_time = 0,
  mocap_start_time = 0,
  outside = c("extend", "NA", "error")
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

- emg_start_time, mocap_start_time:

  Finite scalar start times in seconds on the same reference clock.
  Defaults assume both recordings start at zero. These are known
  offsets; no synchronization or clock drift is estimated.

- outside:

  Handling of target times outside each channel's finite-data support:
  `"extend"` repeats endpoints (compatibility default), `"NA"` leaves
  unavailable times missing, and `"error"` rejects the alignment. Fewer
  than two finite observations produce missing output, or an error under
  `"error"`. Internal gaps are still interpolated; this policy checks
  support boundaries, not internal gap duration. No anti-alias filter is
  added. Endpoint differences within floating-point roundoff are snapped
  to the endpoint (tolerance capped at one millionth of the shorter
  sample interval).

## Value

A list with `mocap`, `emg_aligned` (aligned raw EMG, retained for
compatibility), and `combined` data.frame (processed EMG when
requested).

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
