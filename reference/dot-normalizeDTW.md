# DTW-based normalization

Aligns data using Dynamic Time Warping.

## Usage

``` r
.normalizeDTW(x, norm_length, reference = NULL, ...)
```

## Arguments

- x:

  Data (list of matrices for multiple trials)

- norm_length:

  Target length

- reference:

  Reference trial or "mean"

- ...:

  Additional arguments passed to dtwDistance

## Value

Normalized data
