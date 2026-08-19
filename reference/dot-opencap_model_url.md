# Determine the OpenSim Model URL for an OpenCap Session

OpenCap scales one OpenSim model per session (from the
neutral/calibration trial). Prefer a URL supplied in the session (or
trial) metadata; otherwise construct it from the documented session
endpoint.

## Usage

``` r
.opencap_model_url(session_info, trial, base_url, session_id)
```

## Arguments

- session_info:

  List of session metadata from the API.

- trial:

  List of trial metadata (may be `NULL`).

- base_url, session_id:

  As in
  [`readOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md).

## Value

A character URL for the `.osim` model.
