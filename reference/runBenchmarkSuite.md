# Run a benchmark suite from a manifest

Executes all benchmark rows in a manifest and returns aggregate
summaries.

## Usage

``` r
runBenchmarkSuite(
  manifest,
  data_dir = ".",
  thresholds = defaultBenchmarkThresholds("balanced"),
  alignment = c("truncate", "resample"),
  report_dir = NULL
)
```

## Arguments

- manifest:

  Manifest data.frame or manifest CSV path.
  `prediction_file`/`reference_file` can point to `.csv`, `.mot`,
  `.sto`, or `.trc` files.

- data_dir:

  Base directory for relative manifest file paths.

- thresholds:

  Named threshold list from
  [`defaultBenchmarkThresholds()`](https://x-biosignal.github.io/PhysioMoCap/reference/defaultBenchmarkThresholds.md).

- alignment:

  Alignment mode passed to
  [`benchmarkAgreement()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkAgreement.md).

- report_dir:

  Optional output directory. If supplied, summary and detailed CSV
  reports are written.

## Value

Object of class `"benchmark_suite"` with `summary`, `metrics`,
`manifest`, and `thresholds`.

## References

Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
Rater Reliability." Psychological Bulletin, 86(2), 420-428.

## See also

[`benchmarkAgreement()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkAgreement.md)
for single-trial agreement analysis,
[`createBenchmarkExample()`](https://x-biosignal.github.io/PhysioMoCap/reference/createBenchmarkExample.md)
for generating example benchmark data,
[`print.benchmark_suite()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.benchmark_suite.md)
for displaying suite results.

## Examples

``` r
ex <- createBenchmarkExample(n_trials = 2, seed = 1)
suite <- runBenchmarkSuite(ex$manifest, data_dir = ex$data_dir)
suite$summary
#>      trial_id n_variables n_pass pass_rate  mean_rmse   mean_mae  mean_cor
#> 1 synthetic_1           3      3         1 0.02062899 0.01648134 0.9997790
#> 2 synthetic_2           3      3         1 0.02071876 0.01652174 0.9997751
#>    mean_icc overall_pass
#> 1 0.9997788         TRUE
#> 2 0.9997742         TRUE
```
