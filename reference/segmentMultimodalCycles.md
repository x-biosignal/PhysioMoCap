# Segment matched cycles on native modality sampling grids

Applies explicit shared-clock intervals to multiple modalities from one
participant and trial. All cycle rows and their identifiers are
retained. Intervals are half-open: `[start_time, end_time)`. Recording
coverage is `[origin, origin + n_samples / sampling_rate)`, treating
each acquired sample as the start of a sample interval. No interpolation
or endpoint extension is performed. Boundary roundoff is tolerated up to
one millionth of a sample.

## Usage

``` r
segmentMultimodalCycles(streams, cycles, incomplete = c("error", "retain"))
```

## Arguments

- streams:

  Uniquely named list of modalities. Each entry is a list with `data`
  (nonempty real numeric matrix, time by channels), `sampling_rate`
  (positive finite Hz), `start_time` (finite shared-clock seconds), and
  nonempty character scalars `participant_id` and `trial_id`. All
  entries must declare the same participant and trial.

- cycles:

  Nonempty data.frame with character columns `participant_id`,
  `trial_id`, `side`, `cycle_id` and numeric `start_time`, `end_time` in
  seconds. Composite identifiers must be unique; participant/trial must
  match streams. Additional columns are retained. Missing boundaries are
  reported as incomplete cycles. The caller supplies event-derived
  boundaries; this function does not infer cycles, verify event meaning,
  or select channels anatomically from the side label.

- incomplete:

  Either `"error"` (default) or `"retain"`. In retain mode, incomplete
  modality/cycle segments are `NULL`, with explicit reasons.

## Value

A `multimodal_cycles` list with `cycles`, `segments` (modality then
cycle row; each valid segment contains `data`, `time`, `sample_index`),
`status` (keys, cycle row, modality, complete flag, reason and sample
count), `complete_cycles`, `recordings` metadata and `key_columns`.
Reasons are `ok`, `missing_boundary`, `invalid_interval`,
`out_of_range`, `no_samples`, or `nonfinite_data`. Internal nonfinite
samples invalidate a segment; they are never silently interpolated or
dropped.

## See also

[`summarizeCycleFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeCycleFeatures.md)

## Examples

``` r
s <- list(data = matrix(rep(2, 20), ncol = 1), sampling_rate = 10,
          start_time = 0, participant_id = "P1", trial_id = "T1")
c <- data.frame(participant_id = "P1", trial_id = "T1", side = "L",
                cycle_id = c("C1", "C2"), start_time = 0:1, end_time = 1:2)
z <- segmentMultimodalCycles(list(emg = s, motion = s), c)
z$status
#>   participant_id trial_id side cycle_id cycle_row modality complete reason
#> 1             P1       T1    L       C1         1      emg     TRUE     ok
#> 2             P1       T1    L       C2         2      emg     TRUE     ok
#> 3             P1       T1    L       C1         1   motion     TRUE     ok
#> 4             P1       T1    L       C2         2   motion     TRUE     ok
#>   n_samples
#> 1        10
#> 2        10
#> 3        10
#> 4        10
```
