# Filter signals in a PhysioExperiment object

Applies a Butterworth IIR filter to signal data stored in a
PhysioExperiment object. The filter is applied using zero-phase
filtering (forward-backward) to avoid phase distortion.

## Usage

``` r
filterSignals(
  pe,
  type = c("lowpass", "highpass", "bandpass", "bandstop"),
  cutoff,
  order = 4,
  assay_name = NULL,
  output_assay = NULL
)
```

## Arguments

- pe:

  A PhysioExperiment object.

- type:

  Filter type: "lowpass", "highpass", "bandpass", or "bandstop".

- cutoff:

  Cutoff frequency in Hz. A single value for "lowpass" or "highpass"; a
  length-2 vector `c(low, high)` for "bandpass" or "bandstop".

- order:

  Filter order (default: 4).

- assay_name:

  Which assay to filter. If NULL, uses the first assay.

- output_assay:

  Name for the output assay. If NULL, defaults to
  `"{assay_name}_filtered"`.

## Value

A PhysioExperiment object with filtered data stored as a new assay.

## Details

This function requires the signal package (listed in Suggests). If not
installed, an informative error message with install instructions is
provided.

The Butterworth filter is designed using
[`signal::butter()`](https://rdrr.io/pkg/signal/man/butter.html) and
applied with
[`signal::filtfilt()`](https://rdrr.io/pkg/signal/man/filtfilt.html) for
zero-phase filtering. The cutoff frequency is normalized to the Nyquist
frequency automatically.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

Butterworth S (1930). "On the Theory of Filter Amplifiers." Wireless
Engineer, 7, 536-541.

## See also

[`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md)
for filtering raw vectors and matrices,
[`savgolFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/savgolFilter.md)
for Savitzky-Golay polynomial smoothing,
[`movingAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/movingAverage.md)
for simple moving average smoothing.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- make_mocap_markers(n_time = 500, n_markers = 4, sr = 120)
pe_filt <- filterSignals(pe, type = "lowpass", cutoff = 10)
} # }
```
