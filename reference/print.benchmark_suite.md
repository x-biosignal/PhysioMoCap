# Print benchmark suite summary

Print benchmark suite summary

## Usage

``` r
# S3 method for class 'benchmark_suite'
print(x, ...)
```

## Arguments

- x:

  A `benchmark_suite` object.

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## References

Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
Rater Reliability." Psychological Bulletin, 86(2), 420-428.

## See also

[`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
for running the benchmark suite.

## Examples

``` r
ex <- createBenchmarkExample(n_trials = 2, seed = 1)
suite <- runBenchmarkSuite(ex$manifest, data_dir = ex$data_dir)
print(suite)
#> Benchmark suite
#>   Trials: 2 
#>   Variables: 6 
#>   Variable pass rate: 100.0% 
#>   Trial pass rate: 100.0% 
#>   Mean RMSE: 0.02067 
#>   Mean Cor: 0.9998 
#>   Mean ICC: 0.9998 
```
