# Reaching endpoint accuracy and precision

Computes constant, variable, absolute, and root-mean-square endpoint
error. Variable error uses the population RMS distance about the
endpoint centroid, preserving the identity
`RMSE^2 = constant_error^2 + variable_error^2`.

## Usage

``` r
endpointError(endpoints, target)
```

## Arguments

- endpoints:

  Numeric endpoint vector for a one-dimensional task, or an `n` by 2/3
  numeric matrix with one endpoint per row.

- target:

  Numeric target scalar or vector matching the endpoint dimension.

## Value

A `reaching_endpoint_error` object with constant, variable, absolute,
RMS, and Fitts effective-width errors.

## References

Hancock GR, Butler MS, Fischman MG (1995). On the problem of
two-dimensional error scores: measures and analyses of accuracy, bias,
and consistency. *Journal of Motor Behavior*, 27:241-250.

Fitts PM (1954). The information capacity of the human motor system in
controlling the amplitude of movement. *Journal of Experimental
Psychology*, 47:381-391.
[doi:10.1037/h0055392](https://doi.org/10.1037/h0055392)

## Examples

``` r
endpointError(c(11, 12, 13, 12), target = 10)
#> <reaching_endpoint_error> n=4, dimension=1
#>   constant: 2  variable: 0.7071  absolute: 2
#>   RMSE: 2.121  effective width: 2.922
```
