# Build OpenCap Authentication Header

Constructs an HTTP Authorization header from the supplied API key or the
`OPENCAP_API_KEY` environment variable.

## Usage

``` r
.opencap_auth_header(api_key = NULL)
```

## Arguments

- api_key:

  Character string with the API key, or `NULL` to read from the
  environment variable.

## Value

A named character vector suitable for use as an HTTP header.
