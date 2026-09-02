# PhysioMoCap 0.7.2

New `grfLandmarks()` reads the three classic stance-phase landmarks — the
loading (weight-acceptance) peak, the mid-stance trough and the push-off peak —
from a vertical GRF curve time-normalised to the stance phase. On a
body-weight-normalised curve the landmarks are subject-mass independent, so the
peak-trough-peak pattern can be contrasted across cohorts (the reduced
weight-acceptance modulation of pathological gait). Complements `filterGRF()`,
`computeImpulse()` and `computeLoadingRate()`.

# PhysioMoCap 0.7.1

The generic functional-PCA, waveform-reliability and circular-statistics
implementations moved to PhysioCore (their single source of truth) and are
re-exported here, so `fPCA()`/`reconstructFPCA()`/`registerCurves()`,
`waveformCMC()`/`waveformICC()`/`waveformReliability()` and `circularSummary()`/
`rayleighTest()`/`watsonWilliamsTest()`/`circularLinearCorrelation()` behave
exactly as before. The ggplot2 visualiser `plotFPCA()` stays in this package.

# PhysioMoCap 0.7.0

Movement-disorder quantification: tremor, ataxia and instrumented spasticity.

* Tremor: `tremorSpectrum()` (dependency-free Welch periodogram → dominant
  frequency, in-band power, half-power bandwidth, harmonic ratio in a 3-12 Hz
  band), `tremorAmplitude()` (band-limited RMS) and `tremorMetrics()` (combined,
  tagged rest/postural/kinetic).
* Ataxia: `pathStraightness()` (trajectory straightness / index of curvature) plus
  `limbAtaxiaIndex()` and `gaitAtaxiaIndex()` — honest aggregators of the existing
  validated sub-metrics (`endpointError`, `movementUnits`, `sparc`/`ldlj`,
  `summarizeGaitParameters` CVs, `swayMetrics`) that standardise into a composite
  z only against a supplied healthy reference (no population weights/cut-offs are
  fabricated).
* Instrumented spasticity (Tardieu): `tardieuStretch()` locates the catch (EMG
  reflex onset and/or velocity arrest) → R1; `tardieuScore()` derives R2 and the
  dynamic component R2-R1; `reflexThreshold()` regresses catch angle on stretch
  velocity. Reuses the EMG↔MoCap alignment, envelope and angular-velocity
  primitives already in the package.

# PhysioMoCap 0.6.2

Fixes to the OpenCap -> OpenSim pipeline (from a code review of 0.6.1).

* `runOpenSimFromMarkers()`/`runOpenSimFromOpenCap()` now default `time_range` to
  the **whole trial** (read from the marker file). Previously a `NULL`
  `time_range` left the tool templates' `<time_range>0 1</time_range>` in place,
  silently truncating every trial to its first second.
* `tools` now defaults to `"ik"` (matching the documentation); the previous
  `c("ik","id","so")` default made the bare call error on the ground-reaction
  requirement.
* Inverse kinematics is run before the ID/SO setups are written, so their motion
  input is real rather than an empty placeholder; a failed IK is now reported
  instead of crashing the MOT reader on a 0-byte file, and reused-`workdir` stale
  outputs are no longer attributed to the run.
* `runOpenSimFromOpenCap()` resolves the OpenCap session once (model and markers
  come from the same trial, no duplicate requests), validates `session_id` and a
  supplied `external_loads_file` before downloading, and records the resolved
  trial id.
* `.opencap_model_url` handling tolerates empty/`NA`/non-scalar session metadata;
  a partial `templates` override keeps the bundled defaults for the other tools.

# PhysioMoCap 0.6.1

OpenCap -> OpenSim -> downstream pipeline.

* `runOpenSimFromMarkers()` wires a scaled model and marker `.trc` through
  OpenSim inverse kinematics and, optionally, inverse dynamics and static
  optimization: it writes the tool setup XMLs from the bundled `PhysioOpenSim`
  templates, runs them via `run_opensim_toolchain()`, and parses the outputs
  with `readOpenSimOutputs()`. ID/SO require an `external_loads_file` (markerless
  OpenCap has no ground reactions); `dry_run = TRUE` writes the setups without a
  backend.
* `runOpenSimFromOpenCap()` runs that chain directly from an OpenCap session,
  and `downloadOpenCapModel()` fetches the session's scaled `.osim` model (the
  input the local OpenSim toolchain needs, since OpenCap does the scaling).
* New vignette `opencap-opensim-pipeline` documents both the cloud-kinematics
  route (no local OpenSim) and the local-OpenSim route, with its scope limits.

# PhysioMoCap 0.5.0

Inter-joint coordination analysis.

* `continuousRelativePhase()`: the phase-plane coordination measure (Hamill
  2000) between two joints, with the mean absolute relative phase (MARP).
* `vectorCoding()`: the angle-angle coupling angle, classified per frame into
  in-phase / anti-phase / proximal-phase / distal-phase coordination (Chang
  2008; Needham 2014).
* `coordinationVariability()`: trial-to-trial coordination variability -- the
  deviation phase for CRP (linear SD) or the coupling-angle circular SD for
  vector coding -- a motor-control marker.


# PhysioMoCap 0.4.0

Upper-limb ADL task assessment.

* `adlReachTask()`: assess an ADL arm transport (drinking / feeding / dressing /
  grooming / reaching) from its hand-speed profile -- movement time, peak
  velocity, submovement count and SPARC/LDLJ smoothness -- labelled with the ICF
  code it realises (d560 / d550 / d540 / d520 / d445).
* `nhptDexterity()`: instrumented Nine-Hole-Peg dexterity (ICF d440) from a
  hand-speed profile -- transport count, rate, inter-transport consistency and
  smoothness -- the sensor complement to the timed NHPT score.


# PhysioMoCap 0.3.3

- `poseLengthCorrect()` — segment-length standardisation (camera-distance
  correction): rescales each limb segment along the bone direction to a stable
  reference length, chained proximal to distal. Also available as
  `poseFix(..., length_correct = TRUE)`. Generalised form of the length
  correction in PoseFixeR (Sugiyama, Uno & Matsui 2023).

# PhysioMoCap 0.3.2

- New vignette *"Markerless pose to gait: OpenPose -> poseFix -> analysis"* —
  the end-to-end pose pipeline from ingestion through `poseFix()` cleaning to
  joint angles and a gait metric.

# PhysioMoCap 0.3.1

- `poseFix()` gains left/right leg-swap correction (`deswap = TRUE`): leg-label
  swaps that pose estimators make as the legs cross during gait are corrected by
  restoring trajectory continuity, before the anomaly steps. The number of
  corrections is reported in `metadata()$poseFix$leg_swaps`.

# PhysioMoCap 0.3.0

- `poseFix()` — pose-estimation anomaly detection and correction, connecting
  markerless pose input (`readOpenPose()` / `readMediaPipe()` / `readDeepLabCut()`)
  to the downstream joint-angle / gait / kinematics analysis. Flags keypoints on
  four criteria (low detector confidence, implausible segment lengths,
  frame-to-frame jumps, out-of-range joint angles), then interpolates and smooths
  them. Generalised, name-based, self-referential reimplementation of the method
  in PoseFixeR (Sugiyama, Uno & Matsui 2023, PLOS Comput Biol 19:e1009989).

# PhysioMoCap 0.2.2

- Made the OpenSim MOT/TRC read/write round-trip tests portable to macOS: they
  now assert numerical equality (`expect_equal`) of the recovered data rather
  than bit-identity (`expect_identical`). Writing numeric data through a decimal
  ASCII file (17 significant digits) recovers values exactly on a correctly-
  rounded libc (glibc) but to ~1 ULP on macOS's printf/strtod, so a bit-
  identical round-trip is not a portable guarantee; the data is still preserved
  to full double precision. No writer/reader behaviour changed.

# PhysioMoCap 0.2.1

## Validation

- Bundled an independent OpenSim inverse-dynamics reference
  (`inst/extdata/gait2392_id_reference.rds`) so the `inverseDynamicsRNE()`
  cross-tool test now runs instead of skipping. The fixture is derived from the
  OpenSim gait2392 `subject01_walk1` trial (opensim-models, Apache-2.0) with
  OpenSim 4.6's InverseDynamicsTool; the recursive Newton-Euler solver
  reproduces the OpenSim hip/knee/ankle moments at r > 0.99 and < 8% peak
  error. Generation is documented in `data-raw/gait2392_id_reference*`.

# PhysioMoCap 0.2.0

## New Features

- Added Venus3D CSV reader (`readVenus3D()`) for OptiTrack -> Motive -> Venus3D
  pipeline exports with automatic header metadata parsing.
- Added marker tracking module for resolving frame-by-frame label reassignment:
  - `trackMarkers()` — Hungarian algorithm (via `clue`) or greedy assignment
    for establishing consistent marker identities across frames.
  - `detectSwaps()` — velocity-spike-based swap detection with cross-over
    validation.
  - `correctSwaps()` — automatic swap repair based on detection results.
- `readMoCapAuto()` now auto-detects Venus3D CSV files (by `#Venus3D` header).
- Added `clue` to Suggests for optimal assignment in marker tracking.

# PhysioMoCap 0.1.0

## Major Improvements

- Added beginner-first onboarding utilities:
  - `demoMoCapData()`
  - `quickStartMoCap()`
  - `readMoCapAuto()`
  - `assessMoCapReadiness()`
- Improved CSV robustness for quoted headers in auto/wide parsing.
- Added multi-plate force-plate workflows:
  - `detectForcePlateContacts()`
  - `analyzeForcePlatePE(..., plate_index = "auto" | "all")`
  - `print.forceplate_analysis_multi()`
- Added 3D inverse dynamics support:
  - `inverseDynamics3D()`
  - 3-axis moments and total joint power outputs.
- Expanded onboarding and kinetics test coverage.
- Added getting-started documentation improvements for first-time users.
