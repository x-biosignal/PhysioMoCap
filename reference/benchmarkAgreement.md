# Compute agreement metrics against a reference signal table

Computes per-variable metrics (RMSE, MAE, bias, correlation, R2, ICC,
Bland-Altman LoA width) between prediction and reference data.

## Usage

``` r
benchmarkAgreement(
  prediction,
  reference,
  trial_id = "trial_1",
  thresholds = defaultBenchmarkThresholds("balanced"),
  alignment = c("truncate", "resample")
)
```

## Arguments

- prediction:

  Numeric vector/matrix/data.frame.

- reference:

  Numeric vector/matrix/data.frame.

- trial_id:

  Label used in output rows.

- thresholds:

  Optional named list from
  [`defaultBenchmarkThresholds()`](https://x-biosignal.github.io/PhysioMoCap/reference/defaultBenchmarkThresholds.md).

- alignment:

  Alignment mode when sample lengths differ: `"truncate"` or
  `"resample"`.

## Value

Object of class `"benchmark_agreement"` with `metrics`, `summary`, and
`thresholds`.

## References

Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
Rater Reliability." Psychological Bulletin, 86(2), 420-428.

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`defaultBenchmarkThresholds()`](https://x-biosignal.github.io/PhysioMoCap/reference/defaultBenchmarkThresholds.md)
for threshold configuration,
[`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
for multi-trial benchmarking,
[`blandAltman()`](https://x-biosignal.github.io/PhysioCore//reference/blandAltman.html)
for Bland-Altman agreement analysis.

## Examples

``` r
ref <- data.frame(a = sin(seq(0, 1, length.out = 100)))
pred <- ref + rnorm(100, sd = 0.01)
out <- benchmarkAgreement(pred, ref, trial_id = "demo")
out$summary
#>   trial_id n_variables n_pass pass_rate  mean_rmse   mean_mae  mean_cor
#> 1     demo           1      1         1 0.01033337 0.00814862 0.9991604
#>    mean_icc overall_pass
#> 1 0.9991511         TRUE
```
