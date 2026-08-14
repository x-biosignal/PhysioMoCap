# Changelog

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
