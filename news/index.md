# Changelog

## PhysioMoCap 0.6.2

Fixes to the OpenCap -\> OpenSim pipeline (from a code review of 0.6.1).

- [`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)/[`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md)
  now default `time_range` to the **whole trial** (read from the marker
  file). Previously a `NULL` `time_range` left the tool templates’
  `<time_range>0 1</time_range>` in place, silently truncating every
  trial to its first second.
- `tools` now defaults to `"ik"` (matching the documentation); the
  previous `c("ik","id","so")` default made the bare call error on the
  ground-reaction requirement.
- Inverse kinematics is run before the ID/SO setups are written, so
  their motion input is real rather than an empty placeholder; a failed
  IK is now reported instead of crashing the MOT reader on a 0-byte
  file, and reused-`workdir` stale outputs are no longer attributed to
  the run.
- [`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md)
  resolves the OpenCap session once (model and markers come from the
  same trial, no duplicate requests), validates `session_id` and a
  supplied `external_loads_file` before downloading, and records the
  resolved trial id.
- `.opencap_model_url` handling tolerates empty/`NA`/non-scalar session
  metadata; a partial `templates` override keeps the bundled defaults
  for the other tools.

## PhysioMoCap 0.6.1

OpenCap -\> OpenSim -\> downstream pipeline.

- [`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)
  wires a scaled model and marker `.trc` through OpenSim inverse
  kinematics and, optionally, inverse dynamics and static optimization:
  it writes the tool setup XMLs from the bundled `PhysioOpenSim`
  templates, runs them via
  [`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md),
  and parses the outputs with
  [`readOpenSimOutputs()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenSimOutputs.md).
  ID/SO require an `external_loads_file` (markerless OpenCap has no
  ground reactions); `dry_run = TRUE` writes the setups without a
  backend.
- [`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md)
  runs that chain directly from an OpenCap session, and
  [`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md)
  fetches the session’s scaled `.osim` model (the input the local
  OpenSim toolchain needs, since OpenCap does the scaling).
- New vignette `opencap-opensim-pipeline` documents both the
  cloud-kinematics route (no local OpenSim) and the local-OpenSim route,
  with its scope limits.

## PhysioMoCap 0.5.0

Inter-joint coordination analysis.

- [`continuousRelativePhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/continuousRelativePhase.md):
  the phase-plane coordination measure (Hamill
  2000. between two joints, with the mean absolute relative phase
        (MARP).
- [`vectorCoding()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorCoding.md):
  the angle-angle coupling angle, classified per frame into in-phase /
  anti-phase / proximal-phase / distal-phase coordination (Chang 2008;
  Needham 2014).
- [`coordinationVariability()`](https://x-biosignal.github.io/PhysioMoCap/reference/coordinationVariability.md):
  trial-to-trial coordination variability – the deviation phase for CRP
  (linear SD) or the coupling-angle circular SD for vector coding – a
  motor-control marker.

## PhysioMoCap 0.4.0

Upper-limb ADL task assessment.

- [`adlReachTask()`](https://x-biosignal.github.io/PhysioMoCap/reference/adlReachTask.md):
  assess an ADL arm transport (drinking / feeding / dressing / grooming
  / reaching) from its hand-speed profile – movement time, peak
  velocity, submovement count and SPARC/LDLJ smoothness – labelled with
  the ICF code it realises (d560 / d550 / d540 / d520 / d445).
- [`nhptDexterity()`](https://x-biosignal.github.io/PhysioMoCap/reference/nhptDexterity.md):
  instrumented Nine-Hole-Peg dexterity (ICF d440) from a hand-speed
  profile – transport count, rate, inter-transport consistency and
  smoothness – the sensor complement to the timed NHPT score.

## PhysioMoCap 0.3.3

- [`poseLengthCorrect()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseLengthCorrect.md)
  — segment-length standardisation (camera-distance correction):
  rescales each limb segment along the bone direction to a stable
  reference length, chained proximal to distal. Also available as
  `poseFix(..., length_correct = TRUE)`. Generalised form of the length
  correction in PoseFixeR (Sugiyama, Uno & Matsui 2023).

## PhysioMoCap 0.3.2

- New vignette *“Markerless pose to gait: OpenPose -\> poseFix -\>
  analysis”* — the end-to-end pose pipeline from ingestion through
  [`poseFix()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseFix.md)
  cleaning to joint angles and a gait metric.

## PhysioMoCap 0.3.1

- [`poseFix()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseFix.md)
  gains left/right leg-swap correction (`deswap = TRUE`): leg-label
  swaps that pose estimators make as the legs cross during gait are
  corrected by restoring trajectory continuity, before the anomaly
  steps. The number of corrections is reported in
  `metadata()$poseFix$leg_swaps`.

## PhysioMoCap 0.3.0

- [`poseFix()`](https://x-biosignal.github.io/PhysioMoCap/reference/poseFix.md)
  — pose-estimation anomaly detection and correction, connecting
  markerless pose input
  ([`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)
  /
  [`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md)
  /
  [`readDeepLabCut()`](https://x-biosignal.github.io/PhysioMoCap/reference/readDeepLabCut.md))
  to the downstream joint-angle / gait / kinematics analysis. Flags
  keypoints on four criteria (low detector confidence, implausible
  segment lengths, frame-to-frame jumps, out-of-range joint angles),
  then interpolates and smooths them. Generalised, name-based,
  self-referential reimplementation of the method in PoseFixeR
  (Sugiyama, Uno & Matsui 2023, PLOS Comput Biol 19:e1009989).

## PhysioMoCap 0.2.2

- Made the OpenSim MOT/TRC read/write round-trip tests portable to
  macOS: they now assert numerical equality (`expect_equal`) of the
  recovered data rather than bit-identity (`expect_identical`). Writing
  numeric data through a decimal ASCII file (17 significant digits)
  recovers values exactly on a correctly- rounded libc (glibc) but to ~1
  ULP on macOS’s printf/strtod, so a bit- identical round-trip is not a
  portable guarantee; the data is still preserved to full double
  precision. No writer/reader behaviour changed.

## PhysioMoCap 0.2.1

### Validation

- Bundled an independent OpenSim inverse-dynamics reference
  (`inst/extdata/gait2392_id_reference.rds`) so the
  [`inverseDynamicsRNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamicsRNE.md)
  cross-tool test now runs instead of skipping. The fixture is derived
  from the OpenSim gait2392 `subject01_walk1` trial (opensim-models,
  Apache-2.0) with OpenSim 4.6’s InverseDynamicsTool; the recursive
  Newton-Euler solver reproduces the OpenSim hip/knee/ankle moments at r
  \> 0.99 and \< 8% peak error. Generation is documented in
  `data-raw/gait2392_id_reference*`.

## PhysioMoCap 0.2.0

### New Features

- Added Venus3D CSV reader
  ([`readVenus3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readVenus3D.md))
  for OptiTrack -\> Motive -\> Venus3D pipeline exports with automatic
  header metadata parsing.
- Added marker tracking module for resolving frame-by-frame label
  reassignment:
  - [`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md)
    — Hungarian algorithm (via `clue`) or greedy assignment for
    establishing consistent marker identities across frames.
  - [`detectSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectSwaps.md)
    — velocity-spike-based swap detection with cross-over validation.
  - [`correctSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/correctSwaps.md)
    — automatic swap repair based on detection results.
- [`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
  now auto-detects Venus3D CSV files (by `#Venus3D` header).
- Added `clue` to Suggests for optimal assignment in marker tracking.

## PhysioMoCap 0.1.0

### Major Improvements

- Added beginner-first onboarding utilities:
  - [`demoMoCapData()`](https://x-biosignal.github.io/PhysioMoCap/reference/demoMoCapData.md)
  - [`quickStartMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/quickStartMoCap.md)
  - [`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
  - [`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
- Improved CSV robustness for quoted headers in auto/wide parsing.
- Added multi-plate force-plate workflows:
  - [`detectForcePlateContacts()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectForcePlateContacts.md)
  - `analyzeForcePlatePE(..., plate_index = "auto" | "all")`
  - [`print.forceplate_analysis_multi()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.forceplate_analysis_multi.md)
- Added 3D inverse dynamics support:
  - [`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
  - 3-axis moments and total joint power outputs.
- Expanded onboarding and kinetics test coverage.
- Added getting-started documentation improvements for first-time users.
