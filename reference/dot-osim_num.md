# Format numeric values so they round-trip to identical doubles

Uses 17 significant digits, the shortest fixed precision that is
guaranteed to recover any IEEE-754 double exactly via
[`as.numeric()`](https://rdrr.io/r/base/numeric.html).

## Usage

``` r
.osim_num(v)
```

## Arguments

- v:

  Numeric vector.

## Value

Character vector.
