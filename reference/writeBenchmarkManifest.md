# Write a benchmark manifest template to CSV

Write a benchmark manifest template to CSV

## Usage

``` r
writeBenchmarkManifest(path, n = 1L, overwrite = FALSE)
```

## Arguments

- path:

  Output CSV path.

- n:

  Number of template rows.

- overwrite:

  Logical; overwrite existing file if `TRUE`.

## Value

Invisibly returns `path`.

## References

Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
Between Two Methods of Clinical Measurement." Lancet, 327(8476),
307-310.

## See also

[`benchmarkManifestTemplate()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkManifestTemplate.md)
for creating the manifest data.frame,
[`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
for validating manifest structure.

## Examples

``` r
if (FALSE) { # \dontrun{
writeBenchmarkManifest("benchmark_manifest.csv", n = 3)
} # }
```
