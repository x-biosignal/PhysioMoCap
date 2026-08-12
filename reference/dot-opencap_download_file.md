# Download a File from the OpenCap API

Downloads a file (TRC or MOT) from the given URL to a local destination
with appropriate error handling.

## Usage

``` r
.opencap_download_file(url, auth_header, dest)
```

## Arguments

- url:

  Character string with the full download URL.

- auth_header:

  Named character vector with the Authorization header.

- dest:

  Character string giving the local file path to write to.

## Value

The destination path (invisibly).
