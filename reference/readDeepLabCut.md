# Read DeepLabCut output

Reads DeepLabCut (DLC) pose estimation output from CSV or HDF5 format
and returns a PhysioExperiment object with keypoint coordinates and
confidence scores.

## Usage

``` r
readDeepLabCut(path, fps = 30, format = c("csv", "h5"))
```

## Arguments

- path:

  Path to a DeepLabCut output file (CSV or H5).

- fps:

  Frame rate in Hz (frames per second). Default 30. DeepLabCut does not
  store frame rate in its output, so this must be specified by the user.

- format:

  File format: `"csv"` or `"h5"`. Default `"csv"`.

## Value

A PhysioExperiment with assays:

- keypoint_x:

  X coordinates matrix (frames x bodyparts)

- keypoint_y:

  Y coordinates matrix (frames x bodyparts)

- confidence:

  Detection likelihood matrix (frames x bodyparts)

The `colData` contains columns `label` (bodypart names), `type`
(`"keypoint"`), and `scorer` (the DLC scorer/model name).

The `metadata` list contains `dlc_scorer`, `format`, and `source_file`.

## Details

DeepLabCut outputs pose estimation results in CSV or HDF5 format.

**CSV format** has a 3-row multi-level header:

1.  Row 1: scorer name (the DLC model name)

2.  Row 2: bodypart names

3.  Row 3: coordinate type (x, y, likelihood)

Followed by numeric data where each row is a frame and columns are
grouped as `[x, y, likelihood]` triplets per bodypart.

**H5 format** stores data in a hierarchical HDF5 structure under
`df_with_missing/table`. Requires the `rhdf5` package.

## References

Mathis A, Mamidanna P, Cury KM, Abe T, Murthy VN, Mathis MW, Bethge M
(2018). "DeepLabCut: markerless pose estimation of user-defined body
parts with deep learning." Nature Neuroscience, 21(9), 1281-1289.

## See also

[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md),
[`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md),
[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Read DeepLabCut CSV output
pe <- readDeepLabCut("path/to/DLC_output.csv", fps = 30)

# Read HDF5 format
pe <- readDeepLabCut("path/to/DLC_output.h5", fps = 25, format = "h5")
} # }
```
