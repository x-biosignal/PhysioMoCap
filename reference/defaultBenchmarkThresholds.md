# Get default benchmark thresholds

Returns a named list of threshold values used by benchmark pass/fail
logic.

## Usage

``` r
defaultBenchmarkThresholds(profile = c("balanced", "strict", "lenient"))
```

## Arguments

- profile:

  Threshold profile: `"balanced"` (default), `"strict"`, or `"lenient"`.

## Value

Named list with threshold fields: `rmse_max`, `mae_max`, `bias_abs_max`,
`cor_min`, `icc_min`.

## References

Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
Rater Reliability." Psychological Bulletin, 86(2), 420-428.

## See also

[`benchmarkAgreement()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkAgreement.md)
for computing agreement metrics,
[`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
for running a full benchmark suite.

## Examples

``` r
defaultBenchmarkThresholds()
#> $rmse_max
#> [1] 0.05
#> 
#> $mae_max
#> [1] 0.04
#> 
#> $bias_abs_max
#> [1] 0.02
#> 
#> $cor_min
#> [1] 0.95
#> 
#> $icc_min
#> [1] 0.9
#> 
```
