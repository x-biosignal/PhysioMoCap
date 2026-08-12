# Determine the Result File URL for an OpenCap Trial

Extracts or constructs the download URL for a trial's TRC or MOT file.

## Usage

``` r
.opencap_result_url(trial, data_type, base_url, session_id, trial_id)
```

## Arguments

- trial:

  List with trial metadata from the API.

- data_type:

  Character, either `"markers"` or `"kinematics"`.

- base_url:

  Character string with the base API URL.

- session_id:

  Character string with the session identifier.

- trial_id:

  Character string with the trial identifier.

## Value

A character URL for downloading the file.
