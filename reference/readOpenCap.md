# Read Data from OpenCap Cloud Platform

Downloads motion capture session data from the OpenCap API
(<https://app.opencap.ai>). Marker trajectory data is returned as TRC
format and kinematics data as MOT format, both parsed using the existing
[`readTRC`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
and
[`readMOT`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md)
functions.

## Usage

``` r
readOpenCap(
  session_id,
  trial_id = NULL,
  api_key = NULL,
  data_type = c("markers", "kinematics"),
  base_url = "https://app.opencap.ai/api"
)
```

## Arguments

- session_id:

  Character string giving the OpenCap session identifier (the
  36-character UUID at the end of the session URL).

- trial_id:

  Character string giving the trial identifier within the session. If
  `NULL` (default), the first trial in the session is used.

- api_key:

  Character string with the OpenCap API key. If `NULL` (default), the
  key is read from the `OPENCAP_API_KEY` environment variable.

- data_type:

  Character string specifying the type of data to download. One of
  `"markers"` (TRC marker trajectories) or `"kinematics"` (MOT inverse
  kinematics results). Default is `"markers"`.

- base_url:

  Character string giving the base URL for the OpenCap API. Default is
  `"https://app.opencap.ai/api"`.

## Value

A `PhysioExperiment` object. For `data_type = "markers"`, this contains
`position_x`, `position_y`, and `position_z` assays (from
[`readTRC`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)).
For `data_type = "kinematics"`, this contains a `raw` assay with joint
angle data (from
[`readMOT`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md)).
Session and trial metadata are stored in `metadata()`.

## Details

The function requires the httr package for HTTP requests. If httr is not
installed, a clear error message is given.

Authentication uses an API key passed via the `api_key` parameter or the
`OPENCAP_API_KEY` environment variable. The key is sent as a Bearer
token in the Authorization header.

The download workflow is:

1.  Retrieve session metadata from `GET /sessions/{session_id}/`

2.  List trials from `GET /sessions/{session_id}/trials/`

3.  Download the result file (TRC or MOT) for the selected trial

4.  Parse using
    [`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
    or
    [`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md)

## References

Uhlrich SD, Falisse A, Kidzinski L, Muccini J, Ko M, Chaudhari AS, Hicks
JL, Delp SL (2023). "OpenCap: Human movement dynamics from smartphone
videos." PLoS Computational Biology, 19(10), e1011462.

## See also

[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md),
[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md),
[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Download marker data (requires API key)
pe <- readOpenCap("abcd1234-5678-90ab-cdef-1234567890ab")

# Download kinematics with explicit API key
pe <- readOpenCap(
  session_id = "abcd1234-5678-90ab-cdef-1234567890ab",
  api_key = "my-api-key",
  data_type = "kinematics"
)
} # }
```
