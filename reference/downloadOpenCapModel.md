# Download the OpenSim Model for an OpenCap Session

Downloads the subject-specific, scaled OpenSim model (`.osim`) that
OpenCap produced for a session. This model is the input the local
OpenSim toolchain needs
([`runOpenSimFromMarkers`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)
/
[`runOpenSimFromOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md)):
OpenCap builds and scales it in the cloud from the neutral/calibration
trial, and PhysioOpenSim provides no scaling tool of its own, so the
model must come from OpenCap.

## Usage

``` r
downloadOpenCapModel(
  session_id,
  trial_id = NULL,
  api_key = NULL,
  base_url = "https://app.opencap.ai/api",
  dest = NULL
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

- base_url:

  Character string giving the base URL for the OpenCap API. Default is
  `"https://app.opencap.ai/api"`.

- dest:

  Character path to write the model to. If `NULL` (default) a temporary
  `.osim` file is created.

## Value

The local path to the downloaded `.osim` model (invisibly).

## Details

Requires the httr package and an OpenCap API key (see
[`readOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)).
The model URL is taken from the session metadata when present and
otherwise constructed from the documented session endpoint.

## References

Uhlrich SD, Falisse A, Kidzinski L, Muccini J, Ko M, Chaudhari AS, Hicks
JL, Delp SL (2023). "OpenCap: Human movement dynamics from smartphone
videos." PLoS Computational Biology, 19(10), e1011462.

## See also

[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md),
[`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md),
[`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
osim <- downloadOpenCapModel("abcd1234-5678-90ab-cdef-1234567890ab")
} # }
```
