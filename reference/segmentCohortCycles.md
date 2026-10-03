# Segment cohort recordings while preserving subject and session identity

Reuses the PhysioCore cohort hierarchy and
[`segmentMultimodalCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentMultimodalCycles.md).
Sessions must be `MultiPhysioExperiment` objects with at least two
consistently named streams. No resampling or synchronization is
performed.

## Usage

``` r
segmentCohortCycles(
  x,
  cycles,
  assay = "raw",
  incomplete = c("error", "retain")
)
```

## Arguments

- x:

  A PhysioCore `PhysioCohort`.

- cycles:

  Nonempty data frame with character `subject_id`, `session_id`,
  `trial_id`, `side`, `cycle_id`, and numeric `start_time`, `end_time`.
  Times are seconds relative to each session's master-clock `t0`, as in
  [`PhysioExperiment::streamTimeIndex()`](https://x-biosignal.r-universe.dev/PhysioExperiment/reference/streamTimeIndex.html).
  Trial IDs describe intervals within a session; they are never inferred
  from session IDs. Additional columns are retained. An optional
  `participant_id` must equal `subject_id`.

- assay:

  A single assay name used in every stream (default `"raw"`). Assays
  must be numeric time-by-channel matrices.

- incomplete:

  Passed to
  [`segmentMultimodalCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentMultimodalCycles.md).

## Value

A `multimodal_cycles` object accepted by
[`summarizeCycleFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeCycleFeatures.md).
Canonical keys include subject, session, trial, side and cycle. The
`participant_id` alias is derived from `subject_id`. `cohort_design`
contains the source cohort's subject/session table; `recordings`
contains one entry per selected subject/session/trial context, including
clock and per-modality acquisition metadata. Cycle rows retain input
order.

## Details

Subject-level splits can be made using existing cohort subsetting before
extraction, together with the corresponding cycle rows. This bridge does
not enforce statistical independence or downstream training splits.
Units, anatomical channel meaning, and event detection remain the
caller's responsibility. The selected sessions must share stream names;
feature summarization additionally checks feature names within each
stream. Feature callbacks receive matrices, not recording metadata. For
rate-dependent features, process contexts with their own rate settings
before pooling; a single fixed-rate callback is inappropriate when
session rates differ.

Operates on a `PhysioCohort` multi-subject container (package
PhysioCohort), which is not among this package's dependencies, so the
example cannot run offline and is not executed.

## See also

[`segmentMultimodalCycles()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentMultimodalCycles.md),
[`summarizeCycleFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeCycleFeatures.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# `cohort` is a PhysioCohort object; see the PhysioCohort package.
segmentCohortCycles(cohort, cycles = cohort_cycles)
} # }
```
