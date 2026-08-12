# Create a benchmark manifest template

Produces a template data.frame describing benchmark trials and file
paths.

## Usage

``` r
benchmarkManifestTemplate(n = 1L)
```

## Arguments

- n:

  Number of template rows to create.

## Value

A data.frame manifest template.

## References

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`writeBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeBenchmarkManifest.md)
for writing the template to CSV,
[`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
for validating manifest structure.

## Examples

``` r
benchmarkManifestTemplate(2)
#>   benchmark_id  prediction_file  reference_file modality units
#> 1      trial_1 prediction_1.csv reference_1.csv    mocap    SI
#> 2      trial_2 prediction_2.csv reference_2.csv    mocap    SI
#>   coordinate_system sampling_rate notes
#> 1               lab           100      
#> 2               lab           100      
```
