# Download an OpenCap Trial's Marker (TRC) File to a Path

Returns the local path to the downloaded TRC (unlike
[`readOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)
which parses and discards it), so the file can be fed to the OpenSim
toolchain.

## Usage

``` r
.opencap_download_markers(
  session_id,
  trial_id = NULL,
  api_key = NULL,
  base_url = "https://app.opencap.ai/api",
  dest = NULL
)
```

## Arguments

- session_id, trial_id, api_key, base_url:

  As in
  [`readOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md).

- dest:

  Local path to write the TRC to (default a temporary file).

## Value

The local TRC path.
