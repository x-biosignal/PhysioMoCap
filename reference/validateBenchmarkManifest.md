# Validate a benchmark manifest

Checks structural validity and file existence for benchmark inputs.

## Usage

``` r
validateBenchmarkManifest(manifest, data_dir = ".")
```

## Arguments

- manifest:

  A manifest data.frame or path to a manifest CSV.

- data_dir:

  Base directory used to resolve relative file paths.

## Value

An object of class `"benchmark_manifest_validation"` with fields:
`valid`, `issues`, and `manifest`.

## References

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`benchmarkManifestTemplate()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkManifestTemplate.md)
for creating manifest templates,
[`print.benchmark_manifest_validation()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.benchmark_manifest_validation.md)
for displaying validation results.

## Examples

``` r
m <- benchmarkManifestTemplate(1)
v <- validateBenchmarkManifest(m)
v$valid
#> [1] FALSE
```
