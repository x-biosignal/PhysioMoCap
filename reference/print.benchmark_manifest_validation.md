# Print benchmark manifest validation result

Print benchmark manifest validation result

## Usage

``` r
# S3 method for class 'benchmark_manifest_validation'
print(x, ...)
```

## Arguments

- x:

  A `benchmark_manifest_validation` object.

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## References

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
for performing manifest validation.

## Examples

``` r
ex <- createBenchmarkExample(n_trials = 2, seed = 1)
print(validateBenchmarkManifest(ex$manifest))
#> Benchmark Manifest Validation
#>   Valid: FALSE 
#>   Rows: 2 
#>   Issues:
#>    - Row 1: prediction file not found: ./prediction_1.csv 
#>    - Row 1: reference file not found: ./reference_1.csv 
#>    - Row 2: prediction file not found: ./prediction_2.csv 
#>    - Row 2: reference file not found: ./reference_2.csv 
```
