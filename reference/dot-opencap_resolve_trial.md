# Resolve an OpenCap Session and Target Trial

Fetches session metadata and the trial list, then selects the requested
trial (or the first trial when `trial_id` is `NULL`).

## Usage

``` r
.opencap_resolve_trial(session_id, trial_id, auth_header, base_url)
```

## Arguments

- session_id, trial_id, base_url:

  As in
  [`readOpenCap`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md).

- auth_header:

  Named character vector Authorization header.

## Value

A list with `session_info`, `trial`, and `trial_id`.
