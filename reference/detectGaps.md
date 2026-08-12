# Detect gaps (contiguous NA runs) in assay data

Scans the specified assay of a PhysioExperiment object for contiguous
runs of NA values and returns a data.frame describing each gap.

## Usage

``` r
detectGaps(pe, assay_name = "position_x")
```

## Arguments

- pe:

  A PhysioExperiment object

- assay_name:

  Name of the assay to scan (default: "position_x")

## Value

A data.frame with columns:

- channel - Channel (column) name or index

- start - Start index of the gap (1-based)

- end - End index of the gap (1-based)

- size - Number of consecutive NA values

## References

Federolf PA (2013). "A novel approach to solve the 'missing marker
problem' in marker-based motion analysis that does not require
additional assumptions about the biodynamic model." Journal of
Biomechanics, 46(13), 2173-2178.

## See also

[`reportGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/reportGaps.md),
[`fillGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGaps.md),
[`fillGapsLinear()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsLinear.md)

## Examples

``` r
pe <- PhysioCore::PhysioExperiment(
  assays = S4Vectors::SimpleList(position_x = matrix(c(1, NA, NA, 4), ncol = 1)),
  colData = S4Vectors::DataFrame(label = "M1", type = "marker"),
  samplingRate = 120
)
gaps <- detectGaps(pe, assay_name = "position_x")
```
