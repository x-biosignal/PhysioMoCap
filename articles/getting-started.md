# Getting Started with PhysioMoCap

This guide is designed for first-time users.

## 1. Create demo data

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore

demo <- demoMoCapData(seed = 1)
class(demo$mocap)
#> [1] "PhysioExperiment"
#> attr(,"package")
#> [1] "PhysioCore"
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

## 2. Run one-command quick start

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

## 3. Check data readiness

``` r

qs$readiness
#> MoCap Readiness Report
#>   Score:100% (A+)
#>   Frames: 300 
#>   Markers: 8 
#>   Checks: 8 / 8 passed
head(qs$readiness$checks)
#>         category                   check pass
#> 1      Structure Required assays present TRUE
#> 2       Coverage           Enough frames TRUE
#> 3       Coverage Enough markers/channels TRUE
#> 4       Metadata Sampling rate available TRUE
#> 5       Metadata Sampling rate plausible TRUE
#> 6 Signal quality      Missing-value rate TRUE
#>                                value
#> 1 position_x, position_y, position_z
#> 2                300 (target >= 100)
#> 3                    8 (target >= 5)
#> 4                         120.000 Hz
#> 5        120.000 Hz (target >= 50.0)
#> 6      worst 0.00% (target <= 5.00%)
#>                                                                 recommendation
#> 1 Use readers or preprocessing so required assays exist (e.g. position_x/y/z).
#> 2                             Use a longer recording or merge repeated trials.
#> 3       Ensure all tracked markers are exported and not dropped during import.
#> 4                  Set a positive samplingRate on the PhysioExperiment object.
#> 5     Set the true recording rate or resample data before derivative analyses.
#> 6        Use fillGaps(), fillGapsSpline(), or improve marker tracking quality.
```

## 4. Inspect key outputs

``` r

qs$forceplate$summary
#>   peak_vertical_force max_loading_rate total_impulse n_stances
#> 1            901.6494         5553.832      884.9802         3
head(qs$inverse_dynamics)
#>          time ankle_moment  knee_moment hip_moment ankle_power  knee_power
#> 1 0.000000000           NA           NA         NA          NA          NA
#> 2 0.008333333           NA           NA         NA          NA          NA
#> 3 0.016666667           NA           NA         NA          NA          NA
#> 4 0.025000000     1.102229  0.133703296  -1.350401    1.466754  0.30472000
#> 5 0.033333333     1.447862 -0.005599384  -2.013266    1.858598 -0.01151932
#> 6 0.041666667     1.901312 -0.013758092  -2.492846    2.341628 -0.02514016
#>    hip_power  ankle_fx  ankle_fy   knee_fx    knee_fy    hip_fx     hip_fy
#> 1         NA        NA        NA        NA         NA        NA         NA
#> 2         NA        NA        NA        NA         NA        NA         NA
#> 3         NA        NA        NA        NA         NA        NA         NA
#> 4 -0.7378677 -2.085361 -127.8562 -2.782837  -98.66371 -4.593246  -8.631483
#> 5 -0.7231989 -2.943307 -173.0655 -3.799162 -143.80830 -5.831142 -53.534578
#> 6 -0.4253037 -3.609454 -216.5760 -4.620310 -187.24357 -6.865844 -96.700992
```

## 5. Start from your own file

``` r

trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
if (nzchar(trc_file)) {
  pe <- readMoCapAuto(trc_file)
  assessMoCapReadiness(pe)
}
#> MoCap Readiness Report
#>   Score:75% (C)
#>   Frames: 5 
#>   Markers: 2 
#>   Checks: 6 / 8 passed
#> 
#> Action items:
#>   - Enough frames -> Use a longer recording or merge repeated trials. 
#>   - Enough markers/channels -> Ensure all tracked markers are exported and not dropped during import.
```

You can also run `quickStartMoCap(path = "trial.c3d")` directly.

## 6. Common input entry points

- Marker trajectories:
  [`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md),
  [`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md),
  [`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md),
  [`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
- OpenSim kinematics/forces:
  [`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
  [`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md)
- OpenCap cloud data:
  [`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)

## 7. Common troubleshooting

- If `sampling_rate` is missing, set it explicitly.
- If
  [`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)
  cannot find signals from a matrix, pass a named `signals` list.
- If optional dependency packages are missing (e.g., `c3dr`, `signal`),
  install them from CRAN.
