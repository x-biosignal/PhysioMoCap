# Detect gait events with the Zeni coordinate method

Implements the coordinate-based gait-event detector of Zeni, Richards &
Higginson (2008). Heel strike (initial contact, IC) occurs when a heel
marker reaches its most anterior position relative to a pelvis/COM
reference; toe off (TO) occurs when a toe marker reaches its most
posterior position relative to the same reference. Because events are
keyed to the foot marker *relative to* the pelvis, the method works on
treadmill trials where the body does not translate in the lab frame, and
it returns per-stride IC/TO for both sides across a full trial.

## Usage

``` r
detectEventsZeni(
  pe,
  markers,
  reference = "sacrum",
  ap_axis = NULL,
  direction = NULL,
  body_mass = NULL,
  min_separation = NULL,
  sampling_rate = NULL
)
```

## Arguments

- pe:

  A `PhysioExperiment` with marker `position_x`/`position_y` (and
  optionally `position_z`) assays (frames x markers).

- markers:

  A named list of marker names (columns of the position assays) with
  entries `heel_left`, `heel_right`, `toe_left`, `toe_right`. A side is
  skipped if both its heel and toe entries are `NULL`/missing.

- reference:

  Progression reference: a marker name (e.g. a sacral marker, the
  default `"sacrum"`), or `"com"` to use the whole-body centre of mass
  from
  [`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md)
  (requires `body_mass`).

- ap_axis:

  Anterior-posterior (progression) axis: `"x"`, `"y"`, `"z"` or
  `1`/`2`/`3`. `NULL` (default) auto-detects the axis with the largest
  heel-relative-to-reference excursion.

- direction:

  `+1` or `-1` to orient the AP axis so anterior is positive; `NULL`
  (default) auto-detects it (the fastest relative foot motion, i.e.
  swing, points anterior).

- body_mass:

  Body mass in kg, required only when `reference = "com"`.

- min_separation:

  Minimum number of frames between successive same-type events
  (refractory period). `NULL` (default) estimates it from the dominant
  stride period via autocorrelation.

- sampling_rate:

  Sampling rate in Hz; defaults to `samplingRate(pe)`.

## Value

A `detected_events` data frame with one row per detected event (columns
`event`, `label`, `index`, `time`, `percent`, `method`, `confidence`,
`side`), sorted by frame index.

## Details

The result is a `detected_events` data frame compatible with
[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md);
heel-strike/toe-off rows are named
`left_heel_strike`/`right_heel_strike`/`left_toe_off`/`right_toe_off`
and carry an explicit `side` column.

## References

Zeni JA, Richards JG, Higginson JS (2008). "Two simple methods for
determining gait events during treadmill and overground walking." Gait &
Posture 27(4):710-714.

## See also

[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)
(use `method = "zeni"`),
[`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md),
[`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md).
