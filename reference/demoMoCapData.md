# Create a beginner-friendly demo dataset

Generates synthetic motion capture, force, and EMG data so first-time
users can run package workflows without external files.

## Usage

``` r
demoMoCapData(
  n_frames = 300,
  sampling_rate = 120,
  n_markers = 8,
  emg_sampling_rate = 1000,
  seed = 123
)
```

## Arguments

- n_frames:

  Number of MoCap frames to generate.

- sampling_rate:

  MoCap sampling rate in Hz.

- n_markers:

  Number of markers in the synthetic marker set.

- emg_sampling_rate:

  EMG sampling rate in Hz.

- seed:

  Optional random seed for reproducibility. Set to `NULL` to skip
  setting a seed.

## Value

A named list with:

- mocap:

  A `PhysioExperiment` with `position_x`, `position_y`, `position_z`
  assays.

- grf:

  Numeric vector of synthetic vertical GRF.

- forces:

  Matrix with `force_x`, `force_y`, `force_z` columns.

- joints:

  Data frame with 2D joint-center coordinates for ankle, knee, and hip.

- joint_angles:

  Data frame with ankle/knee/hip joint angles (radians).

- emg:

  Matrix of synthetic EMG channels.

- sampling_rate:

  MoCap sampling rate (Hz).

- emg_sampling_rate:

  EMG sampling rate (Hz).

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`quickStartMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/quickStartMoCap.md)
for a complete getting-started workflow,
[`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
for data quality assessment.

## Examples

``` r
demo <- demoMoCapData(seed = 1)
demo$mocap
#> class: PhysioExperiment
#> dim: 300 x 8 
#> assays(3): position_x, position_y, position_z
#> samplingRate: 120 Hz
#> channels(8): Pelvis_R, Pelvis_L, Knee_R, Knee_L, Ankle_R ...
#> colData names(2): label, type
head(demo$joints)
#>       ankle_x    ankle_y      knee_x    knee_y       hip_x     hip_y     toe_x
#> 1 0.000000000 0.06000000 0.001986693 0.4696013 0.001947092 0.8592106 0.1500000
#> 2 0.001255810 0.05998027 0.002598162 0.4693132 0.002232419 0.8589479 0.1512558
#> 3 0.002506665 0.05992115 0.003199377 0.4689488 0.002508936 0.8586499 0.1525067
#> 4 0.003747626 0.05982287 0.003787965 0.4685096 0.002775551 0.8583178 0.1537476
#> 5 0.004973798 0.05968583 0.004361604 0.4679974 0.003031213 0.8579528 0.1549738
#> 6 0.006180340 0.05951057 0.004918030 0.4674141 0.003274912 0.8575564 0.1561803
#>        toe_y
#> 1 0.02000000
#> 2 0.01998027
#> 3 0.01992115
#> 4 0.01982287
#> 5 0.01968583
#> 6 0.01951057
```
