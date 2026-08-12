# PhysioMoCap TODO

## External Gold-Standard Benchmarking

Finalize candidate public datasets and licenses for redistribution/use.

Define dataset-specific mapping tables (joint names, units, coordinate
frames).

Create dataset adapters into the benchmark manifest format.

Run
[`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
on each dataset and archive reports.

Set acceptance thresholds per modality/task (gait, jump, running).

Add regression gates in CI using fixed benchmark snapshots.

## Biomechanics Accuracy and Robustness

Add validation cases for multi-forceplate assignment edge conditions.

Add additional sign-convention and frame-transform checks for kinetics.

Expand
[`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
tests with reference trajectories and edge cases.

Add benchmark comparisons against OpenSim reference outputs where
available.

## Beginner and First-Time User Experience

Add a “common errors” vignette with before/after fixes.

Add template manifest and example reports under `inst/extdata` for quick
start.

Add a one-command benchmark runner wrapper for real datasets.

## Release and Submission Operations

Update `NEWS.md` for next version bump.

Refresh `inst/CRAN-SUBMISSION.md` with final environment logs before
submission.

Confirm final `R CMD check --as-cran` in online environment.
