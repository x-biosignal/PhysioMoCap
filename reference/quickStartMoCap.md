# Run a one-command beginner workflow

Runs a compact end-to-end pipeline for first-time users: kinematics
derivatives, readiness scoring, and optional force-plate,
inverse-dynamics, and EMG modules.

## Usage

``` r
quickStartMoCap(
  n_frames = 300,
  sampling_rate = NULL,
  emg_sampling_rate = 1000,
  seed = 123,
  mocap = NULL,
  path = NULL,
  format = c("auto", "csv", "c3d", "trc", "bvh", "amc"),
  forces = NULL,
  joints = NULL,
  joint_angles = NULL,
  emg = NULL
)
```

## Arguments

- n_frames:

  Number of MoCap frames for demo mode.

- sampling_rate:

  MoCap sampling rate in Hz. In non-demo mode, if `NULL`, uses
  `samplingRate(mocap)`.

- emg_sampling_rate:

  EMG sampling rate in Hz.

- seed:

  Random seed for reproducibility in demo mode.

- mocap:

  Optional `PhysioExperiment` object to analyze.

- path:

  Optional file path to load via
  [`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md).

- format:

  Format hint passed to
  [`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
  when `path` is used.

- forces:

  Optional force matrix/data.frame for force-plate analysis.

- joints:

  Optional joint-center data for inverse dynamics.

- joint_angles:

  Optional joint-angle data for inverse dynamics.

- emg:

  Optional EMG matrix for EMG processing.

## Value

An object of class `"mocap_quickstart"` containing generated outputs,
readiness report, and notes for skipped/failed optional modules.

## Details

If `mocap` or `path` is omitted, synthetic demo data are generated.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`demoMoCapData()`](https://x-biosignal.github.io/PhysioMoCap/reference/demoMoCapData.md)
for generating demo data without analysis,
[`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
for data quality assessment,
[`print.mocap_quickstart()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.mocap_quickstart.md)
for formatted display of results.

## Examples

``` r
qs <- quickStartMoCap(seed = 1)
qs
#> PhysioMoCap Quick Start
#>   Source: demo 
#>   Frames: 300 
#>   Markers: 8 
#>   Sampling rate: 120.000 Hz
#>   Readiness:100% (A+)
#> 
#> Generated outputs:
#>   - velocity / acceleration: TRUE 
#>   - forceplate summary: TRUE 
#>   - inverse dynamics: TRUE 
#>   - EMG processed/aligned: TRUE / TRUE 
#> 
#> Next steps:
#>   1) Check readiness details: x$readiness
#>   2) View force summary: x$forceplate$summary
#>   3) Start from your own file: quickStartMoCap(path = 'trial.c3d')
```
