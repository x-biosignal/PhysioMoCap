# Print method for detected events

Print method for detected events

## Usage

``` r
# S3 method for class 'detected_events'
print(x, ...)
```

## Arguments

- x:

  A detected_events object

- ...:

  Additional arguments (unused)

## Examples

``` r
set.seed(123)
vGRF <- c(rep(0, 100), sin(seq(0, pi, length.out = 500)) * 800, rep(0, 400))
vGRF <- vGRF + rnorm(1000, 0, 10)
ev <- detectEvents(as.matrix(vGRF), schema_gait,
  signals = list(vGRF = vGRF), sampling_rate = 1000)
print(ev)
#> Detected Events
#> Schema: gait 
#> Sampling rate: 1000 Hz
#> Total samples: 1000 
#> 
#>  event         label index        time    percent        method confidence
#>     ms     Midstance     2 0.001128671  0.1001001 zero_crossing       0.85
#>    hs1   Heel Strike     3 0.002000000  0.2002002     threshold       0.90
#>     ho      Heel Off     3 0.002000000  0.2002002     threshold       0.90
#>    hs2 Heel Strike 2     3 0.002000000  0.2002002     threshold       0.90
#>     to       Toe Off     4 0.003000000  0.3003003     threshold       0.90
#>     ff     Foot Flat   360 0.359000000 35.9359359          peak       0.95
```
