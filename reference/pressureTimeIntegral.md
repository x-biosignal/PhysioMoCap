# Calculate the plantar pressure-time integral

Uses trapezoidal integration over the sampled duration. The force-time
integral converts kPa times mm-squared to N using `force_factor`.

## Usage

``` r
pressureTimeIntegral(pm, force_factor = 0.001)
```

## Arguments

- pm:

  A `pressure_movie`.

- force_factor:

  Conversion from pressure times cell area to force. The default `1e-3`
  converts kPa times mm-squared to N; use `0.1` for kPa times
  cm-squared.

## Value

A numeric matrix of pressure-time integrals in kPa-s. Attribute `"fti"`
is the total force-time integral in N-s.

## Examples

``` r
pm <- pressureMovie(array(100, c(2, 2, 11)), 100, dx = 5, dy = 5)
pressureTimeIntegral(pm)
#>      [,1] [,2]
#> [1,]   10   10
#> [2,]   10   10
#> attr(,"fti")
#> [1] 1
```
