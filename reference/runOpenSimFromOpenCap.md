# Run the local OpenSim toolchain directly from an OpenCap session

End-to-end bridge: downloads an OpenCap session's scaled OpenSim model
([`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md))
and marker `.trc`, then runs the local OpenSim toolchain
([`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)).
Requires a working OpenSim backend (native PhysioOpenSim build or the
`opensim-cmd` CLI) and, for ID/SO, an `external_loads_file` (OpenCap is
markerless and has no ground reactions).

## Usage

``` r
runOpenSimFromOpenCap(
  session_id,
  trial_id = NULL,
  api_key = NULL,
  base_url = "https://app.opencap.ai/api",
  model_file = NULL,
  tools = c("ik", "id", "so"),
  external_loads_file = NULL,
  time_range = NULL,
  workdir = NULL,
  templates = NULL,
  cli = NULL,
  require_external_loads = TRUE,
  dry_run = FALSE
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

- model_file:

  Optional local `.osim` model; if `NULL` (default) it is downloaded
  from the session with
  [`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md).

- tools, external_loads_file, time_range, workdir, templates, cli,
  require_external_loads, dry_run:

  Passed to
  [`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md).

## Value

An `opensim_run` object (see
[`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md)).

## See also

[`runOpenSimFromMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromMarkers.md),
[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md),
[`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- runOpenSimFromOpenCap(
  session_id = "abcd1234-5678-90ab-cdef-1234567890ab",
  tools = c("ik", "id", "so"), external_loads_file = "walk_grf.xml")
res$outputs
} # }
```
