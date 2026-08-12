# Read Venus3D CSV Data

Reads motion capture data exported from the OptiTrack -\> Motive -\>
Venus3D pipeline. The Venus3D CSV format uses `#`-prefixed header lines
for metadata and stores 3D marker coordinates in wide format with
columns like `1(X)`, `1(Y)`, `1(Z)`, `2(X)`, etc.

## Usage

``` r
readVenus3D(path, marker_names = NULL)
```

## Arguments

- path:

  Path to the Venus3D CSV file.

- marker_names:

  Optional character vector of marker names to assign. Must match the
  number of markers in the file. If `NULL` (default), markers are
  labelled `P1`, `P2`, ... based on the Point Type header, or `M1`,
  `M2`, ... if that header is absent.

## Value

A PhysioExperiment with assays:

- position_x:

  X coordinates matrix (frames x markers)

- position_y:

  Y coordinates matrix (frames x markers)

- position_z:

  Z coordinates matrix (frames x markers)

The `colData` contains columns `label` (marker names) and `type`
(`"marker"`). The `metadata` list contains `format`, `source_file`,
`format_version`, `units`, `coordinate_system`, and `time` (numeric
vector of frame times).

## Details

Because Venus3D randomly reassigns marker labels across frames,
downstream use of
[`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md)
is typically required to establish consistent marker identities.

## References

Venus3D Software Documentation, C-Motion Inc.

## See also

[`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md)
for resolving Venus3D's random label assignment,
[`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md)
for generic CSV formats,
[`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
for automatic format detection.

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readVenus3D("capture.csv")

# Assign meaningful marker names
pe <- readVenus3D("capture.csv",
                  marker_names = c("Hip", "Knee", "Ankle"))

# Follow with marker tracking to resolve label shuffling
pe_tracked <- trackMarkers(pe)
} # }
```
