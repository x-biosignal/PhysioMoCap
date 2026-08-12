# Gold-Standard Data Download and Benchmark Setup

This vignette shows how to move from dataset discovery to a runnable
benchmark manifest for external gold-standard validation.

## 1. Preconditions

To download open datasets, you need:

1.  `bash` and `wget`
2.  DNS/HTTPS access to external hosts (for example, `physionet.org`,
    `ncbi.nlm.nih.gov`, `ftp.ncbi.nlm.nih.gov`)

In this monorepo, the helper script is:

- `publication/scripts/download_open_medrehab_gold_data.sh`

``` bash
bash publication/scripts/download_open_medrehab_gold_data.sh data/external
```

Controlled datasets (for example, MIMIC-IV full, eICU, MOST, OAI
controlled resources) require account approval and DUA steps before
download.

## 2. Create a benchmark manifest

Use a template and then replace file paths with your real
prediction/reference pairs (`.csv`, `.mot`, `.sto`, `.trc`).

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore

manifest <- benchmarkManifestTemplate(n = 2)
manifest
#>   benchmark_id  prediction_file  reference_file modality units
#> 1      trial_1 prediction_1.csv reference_1.csv    mocap    SI
#> 2      trial_2 prediction_2.csv reference_2.csv    mocap    SI
#>   coordinate_system sampling_rate notes
#> 1               lab           100      
#> 2               lab           100
```

Write the template to CSV if needed:

``` r

tmp_manifest <- tempfile("benchmark_manifest_", fileext = ".csv")
writeBenchmarkManifest(tmp_manifest, n = 2, overwrite = TRUE)
tmp_manifest
#> [1] "/tmp/Rtmp3pGgBX/benchmark_manifest_4e926728959f.csv"
```

## 3. Point manifest rows to your downloaded files

Below is a minimal pattern. File names are examples; replace them with
paths that exist in your local `data_dir`.

``` r

data_dir <- tempfile("gold_data_")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

# Demo-only placeholder files so the validation example can run end-to-end.
pred <- data.frame(knee_angle = rnorm(200, sd = 0.02),
                   hip_angle = rnorm(200, sd = 0.02))
ref  <- data.frame(knee_angle = pred$knee_angle + rnorm(200, sd = 0.01),
                   hip_angle = pred$hip_angle + rnorm(200, sd = 0.01))

utils::write.csv(pred, file.path(data_dir, "prediction_trial1.csv"), row.names = FALSE)
utils::write.csv(ref,  file.path(data_dir, "reference_trial1.csv"), row.names = FALSE)

manifest <- benchmarkManifestTemplate(n = 1)
manifest$benchmark_id[1] <- "trial1_external"
manifest$prediction_file[1] <- "prediction_trial1.csv"
manifest$reference_file[1] <- "reference_trial1.csv"
manifest$modality[1] <- "mocap"
manifest$units[1] <- "SI"
manifest$sampling_rate[1] <- 100
manifest
#>      benchmark_id       prediction_file       reference_file modality units
#> 1 trial1_external prediction_trial1.csv reference_trial1.csv    mocap    SI
#>   coordinate_system sampling_rate notes
#> 1               lab           100
```

## 4. Validate manifest integrity

``` r

v <- validateBenchmarkManifest(manifest, data_dir = data_dir)
v
#> Benchmark Manifest Validation
#>   Valid: TRUE 
#>   Rows: 1
```

If `v$valid` is `FALSE`, inspect `v$issues` and fix file paths or
required columns (`benchmark_id`, `prediction_file`, `reference_file`).

## 5. Run benchmark suite

``` r

suite <- runBenchmarkSuite(
  manifest = manifest,
  data_dir = data_dir,
  thresholds = defaultBenchmarkThresholds("balanced"),
  alignment = "truncate"
)

suite$suite_summary
#>   n_trials n_variables overall_pass_rate trial_pass_rate   mean_rmse
#> 1        1           2                 0               0 0.009851429
#>      mean_mae  mean_cor  mean_icc
#> 1 0.007969677 0.9003743 0.8960318
head(suite$metrics)
#>          trial_id   variable   n        rmse         mae         bias       cor
#> 1 trial1_external knee_angle 200 0.010027543 0.008132009 0.0011414642 0.9000071
#> 2 trial1_external  hip_angle 200 0.009675316 0.007807344 0.0005392446 0.9007414
#>          r2       icc  loa_width  pass
#> 1 0.8100127 0.8942128 0.03914974 FALSE
#> 2 0.8113351 0.8978508 0.03796262 FALSE
```

## 6. Replace placeholders with real external data

1.  Keep the same manifest contract.
2.  Replace the placeholder paths with real downloaded files (`.csv`,
    `.mot`, `.sto`, `.trc`).
3.  Re-run
    [`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
    and
    [`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md).
4.  Optionally set `report_dir` in
    [`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
    to export reports.

For repository-level data availability and source links, see:

- `publication/data_availability_and_download_guide_ja.md`
- `publication/gold_standard_data_search_framework_medrehab_ja.md`
