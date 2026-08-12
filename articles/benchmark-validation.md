# Benchmark Validation Workflow

This vignette shows a complete validation-benchmark workflow that works
even before external gold-standard datasets are attached.

## 1. Create a benchmark bundle

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore

ex <- createBenchmarkExample(
  n_trials = 3,
  n_samples = 250,
  noise_sd = 0.02,
  seed = 1
)

ex$manifest
#>   benchmark_id  prediction_file  reference_file        modality     units
#> 1  synthetic_1 prediction_1.csv reference_1.csv synthetic_mocap arbitrary
#> 2  synthetic_2 prediction_2.csv reference_2.csv synthetic_mocap arbitrary
#> 3  synthetic_3 prediction_3.csv reference_3.csv synthetic_mocap arbitrary
#>   coordinate_system sampling_rate             notes
#> 1               lab           100 synthetic example
#> 2               lab           100 synthetic example
#> 3               lab           100 synthetic example
```

## 2. Validate manifest integrity

``` r

v <- validateBenchmarkManifest(ex$manifest, data_dir = ex$data_dir)
v
#> Benchmark Manifest Validation
#>   Valid: TRUE 
#>   Rows: 3
```

## 3. Run benchmark suite

``` r

suite <- runBenchmarkSuite(
  manifest = ex$manifest,
  data_dir = ex$data_dir,
  thresholds = defaultBenchmarkThresholds("balanced"),
  alignment = "truncate"
)

suite
#> Benchmark suite
#>   Trials: 3 
#>   Variables: 9 
#>   Variable pass rate: 100.0% 
#>   Trial pass rate: 100.0% 
#>   Mean RMSE: 0.02078 
#>   Mean Cor: 0.9998 
#>   Mean ICC: 0.9998
suite$suite_summary
#>   n_trials n_variables overall_pass_rate trial_pass_rate  mean_rmse   mean_mae
#> 1        3           9                 1               1 0.02078088 0.01658273
#>    mean_cor mean_icc
#> 1 0.9997714 0.999771
head(suite$metrics)
#>      trial_id    variable   n       rmse        mae          bias       cor
#> 1 synthetic_1   hip_angle 250 0.01921736 0.01516674  4.433875e-04 0.9997441
#> 2 synthetic_1  knee_angle 250 0.02118169 0.01677395  4.623760e-04 0.9997729
#> 3 synthetic_1 ankle_angle 250 0.02105554 0.01713104 -1.814594e-03 0.9998297
#> 4 synthetic_2   hip_angle 250 0.02123389 0.01681300 -2.302108e-05 0.9996858
#> 5 synthetic_2  knee_angle 250 0.02048568 0.01646742 -9.520477e-04 0.9997865
#> 6 synthetic_2 ankle_angle 250 0.01985484 0.01586132  8.325096e-04 0.9998473
#>          r2       icc  loa_width pass
#> 1 0.9994883 0.9997440 0.07546170 TRUE
#> 2 0.9995459 0.9997718 0.08317743 TRUE
#> 3 0.9996595 0.9998276 0.08239407 TRUE
#> 4 0.9993718 0.9996869 0.08340224 TRUE
#> 5 0.9995731 0.9997865 0.08037654 TRUE
#> 6 0.9996946 0.9998467 0.07791708 TRUE
```

## 4. Export reports

``` r

report_dir <- tempfile("benchmark_report_")
runBenchmarkSuite(
  manifest = ex$manifest,
  data_dir = ex$data_dir,
  thresholds = defaultBenchmarkThresholds("balanced"),
  report_dir = report_dir
)
#> Benchmark suite
#>   Trials: 3 
#>   Variables: 9 
#>   Variable pass rate: 100.0% 
#>   Trial pass rate: 100.0% 
#>   Mean RMSE: 0.02078 
#>   Mean Cor: 0.9998 
#>   Mean ICC: 0.9998

list.files(report_dir)
#> [1] "benchmark_metrics.csv"       "benchmark_suite_summary.csv"
#> [3] "benchmark_summary.csv"
```

## 5. Use real gold-standard data later

1.  Keep the same manifest columns (`benchmark_id`, `prediction_file`,
    `reference_file`).
2.  Replace file paths with your real prediction/reference files
    (`.csv`, `.mot`, `.sto`, `.trc`).
3.  Re-run
    [`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
    and
    [`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md).

This keeps validation infrastructure stable while datasets evolve.
