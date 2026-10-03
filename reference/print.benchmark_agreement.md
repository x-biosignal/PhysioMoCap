# Print benchmark agreement summary

Print benchmark agreement summary

## Usage

``` r
# S3 method for class 'benchmark_agreement'
print(x, ...)
```

## Arguments

- x:

  A `benchmark_agreement` object.

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## References

Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
Rater Reliability." Psychological Bulletin, 86(2), 420-428.

## See also

[`benchmarkAgreement()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkAgreement.md)
for computing agreement metrics.

## Examples

``` r
ref <- data.frame(a = sin(seq(0, 1, length.out = 100)))
pred <- ref + rnorm(100, sd = 0.01)
print(benchmarkAgreement(pred, ref, trial_id = "demo"))
#> Benchmark agreement
#>   Trial: demo 
#>   Variables: 1 
#>   Pass rate: 100.0% 
#>   Overall pass: TRUE 
#>   Mean RMSE: 0.009967 
#>   Mean Cor: 0.9992 
#>   Mean ICC: 0.9992 
```
