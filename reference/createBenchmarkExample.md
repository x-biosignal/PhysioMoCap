# Create a synthetic benchmark dataset bundle

Generates prediction/reference CSV pairs and a manifest for dry-run
validation benchmarking when external data are not yet available.

## Usage

``` r
createBenchmarkExample(
  output_dir = tempdir(),
  n_trials = 3L,
  n_samples = 300L,
  variables = c("hip_angle", "knee_angle", "ankle_angle"),
  noise_sd = 0.02,
  seed = 1
)
```

## Arguments

- output_dir:

  Output directory where files are written.

- n_trials:

  Number of synthetic trials.

- n_samples:

  Samples per trial.

- variables:

  Character vector of variable names.

- noise_sd:

  Prediction noise SD relative to the generated reference.

- seed:

  Random seed.

## Value

A list with `manifest`, `manifest_path`, and `data_dir`.

## References

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
for running the benchmark suite,
[`benchmarkManifestTemplate()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkManifestTemplate.md)
for creating empty manifest templates.

## Examples

``` r
ex <- createBenchmarkExample(n_trials = 2, seed = 1)
runBenchmarkSuite(ex$manifest, data_dir = ex$data_dir)
#> Benchmark suite
#>   Trials: 2 
#>   Variables: 6 
#>   Variable pass rate: 100.0% 
#>   Trial pass rate: 100.0% 
#>   Mean RMSE: 0.02067 
#>   Mean Cor: 0.9998 
#>   Mean ICC: 0.9998 
```
