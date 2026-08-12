# Read GaitRec Dataset

Reads ground reaction force (GRF) data or spatiotemporal parameters from
the GaitRec dataset format (Horsak et al., 2020). GaitRec is a
large-scale clinical gait dataset containing GRF waveforms and gait
parameters from patients with various lower-limb orthopaedic conditions
and healthy controls.

## Usage

``` r
readGaitRec(
  path,
  type = c("grf", "parameters"),
  sr = 1000,
  sep = ",",
  subject_id = NULL
)
```

## Arguments

- path:

  Path to a GaitRec CSV file or a directory containing GaitRec CSV
  files. When a directory is given, all CSV files matching the specified
  `type` are read and combined.

- type:

  Type of data to read: `"grf"` for ground reaction force waveforms or
  `"parameters"` for spatiotemporal parameters. Default `"grf"`.

- sr:

  Sampling rate in Hz. Default `1000` for GaitRec GRF data. For
  time-normalised waveforms (101 data points representing 0–100\\ gait
  cycle), this value is used as a nominal sampling rate in the resulting
  PhysioExperiment object.

- sep:

  Column separator in the CSV file. Default `","`. Set to `"\t"` for
  tab-separated files.

- subject_id:

  Optional subject identifier string to store in the returned object's
  metadata. When `path` is a directory this is ignored and identifiers
  are extracted from file names.

## Value

For `type = "grf"`: a `PhysioExperiment` object with a `"raw"` assay
containing the GRF data matrix (time points x channels). The `colData`
records channel labels, force component (`"Fx"`, `"Fy"`, `"Fz"`), plate
number, and unit (`"N"`). Metadata includes `source_file`, `format`, and
`subject_id`.

For `type = "parameters"`: a `data.frame` with spatiotemporal gait
parameters extracted from the CSV file.

## Details

### GaitRec GRF file format

GaitRec GRF CSV files typically contain columns for time and force
components from two force plates:

- A time column (e.g., `"time"`, `"Time"`, `"t"`)

- Force columns following naming patterns like `"Fx1"`, `"Fy1"`,
  `"Fz1"`, `"Fx2"`, `"Fy2"`, `"Fz2"` (plate number suffix) or
  `"FP1_Fx"`, `"FP1_Fy"`, `"FP1_Fz"`, `"FP2_Fx"`, etc. (plate prefix)

The function auto-detects force column naming patterns and extracts the
component (x/y/z) and plate number. Columns that do not match recognised
force patterns are stored in `metadata(pe)$extra_columns` as a
data.frame.

Time-normalised waveforms (101 data points, 0–100\\ also supported. The
parser detects these by row count and stores a `percent_gait_cycle`
vector in the metadata.

## References

Horsak B, Slijepcevic D, Raberger A-M, Schwab C, Worisch M, Zeppelzauer
M (2020). "GaitRec, a large-scale ground reaction force dataset of
healthy and impaired gait." *Scientific Data*, 7, 143.
[doi:10.1038/s41597-020-0481-z](https://doi.org/10.1038/s41597-020-0481-z)

## See also

[`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md)
for generic CSV motion capture data,
[`filterGRF()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterGRF.md)
for low-pass filtering GRF signals,
[`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
for force plate analysis.

## Examples

``` r
if (FALSE) { # \dontrun{
# Read a single GRF file
pe <- readGaitRec("path/to/gaitrec_grf.csv")

# Read spatiotemporal parameters
params <- readGaitRec("path/to/gaitrec_params.csv", type = "parameters")

# Read with tab separator
pe <- readGaitRec("path/to/gaitrec.tsv", sep = "\t")
} # }
```
