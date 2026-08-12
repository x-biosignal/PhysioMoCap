# Read Motion Capture CSV Data

Generic CSV reader that handles common motion capture CSV exports from
various systems including Qualisys, Vicon, and generic marker position
formats. Returns a PhysioExperiment with `position_x`, `position_y`, and
`position_z` assays.

## Usage

``` r
readMoCapCSV(
  path,
  format = c("auto", "xyz", "wide", "long", "qualisys", "vicon"),
  sampling_rate = NULL,
  header_rows = 1L,
  skip = 0L,
  sep = ",",
  marker_names = NULL,
  coord_columns = NULL
)
```

## Arguments

- path:

  Path to the CSV file.

- format:

  Format hint: `"auto"` (detect), `"xyz"` (columns like `marker1_x`,
  `marker1_y`, `marker1_z`), `"wide"` (columns like `Time`, `M1X`,
  `M1Y`, `M1Z`), `"long"` (columns: `frame`, `marker`, `x`, `y`, `z`),
  `"qualisys"` (Qualisys TSV export), or `"vicon"` (Vicon CSV export).
  Default `"auto"`.

- sampling_rate:

  Sampling rate in Hz. Required if not detectable from the file (e.g.,
  from a Time column). If `NULL` and not detectable, an error is raised.

- header_rows:

  Number of header rows. Default 1.

- skip:

  Number of lines to skip before reading. Default 0.

- sep:

  Column separator. Default `","`.

- marker_names:

  Explicit marker names (overrides auto-detection from column names).
  Must match the number of markers detected from columns.

- coord_columns:

  Mapping of coordinate types as a named list of regex patterns, e.g.,
  `list(x = "_X$", y = "_Y$", z = "_Z$")`. Used only when `format` is
  `"wide"` or `"auto"`.

## Value

A PhysioExperiment with assays:

- position_x:

  X coordinates matrix (frames x markers)

- position_y:

  Y coordinates matrix (frames x markers)

- position_z:

  Z coordinates matrix (frames x markers)

The `colData` contains columns `label` (marker names) and `type`
(`"marker"`). The `metadata` list contains `format`, `source_file`, and
optionally `time` (if a Time column was found).

## Details

### Auto-detection logic

When `format = "auto"`, the function inspects column names:

1.  If columns match `*_x`, `*_y`, `*_z` pattern (case-insensitive) with
    consistent marker prefixes, the `"xyz"` format is used.

2.  If columns match `*X`, `*Y`, `*Z` suffix pattern, the `"wide"`
    format is used.

3.  If the header contains "Qualisys" or "QTM", the `"qualisys"` format
    is used.

4.  If columns include `frame`, `marker`, `x`, `y`, `z`
    (case-insensitive), the `"long"` format is used.

If a `Time` or `time` column is present and contains numeric values, the
sampling rate is computed from the median time step. An explicit
`sampling_rate` argument always takes precedence.

## References

Wickham H (2014). "Tidy Data." Journal of Statistical Software, 59(10),
1-23.

## See also

[`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)
and
[`readAMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readAMC.md)
for Acclaim skeleton and motion files,
[`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
for automatic format detection.

## Examples

``` r
if (FALSE) { # \dontrun{
# Read xyz-format CSV
pe <- readMoCapCSV("markers.csv", sampling_rate = 120)

# Read with auto-detection from Time column
pe <- readMoCapCSV("markers.csv")

# Read tab-separated file
pe <- readMoCapCSV("qualisys_export.tsv", format = "qualisys", sep = "\t")

# Override marker names
pe <- readMoCapCSV("data.csv", marker_names = c("Hip", "Knee", "Ankle"),
                   sampling_rate = 100)
} # }
```
